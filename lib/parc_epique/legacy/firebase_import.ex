defmodule ParcEpique.Legacy.FirebaseImport do
  @moduledoc """
  Imports a Firebase Realtime Database export (`database.json`) of the old
  parc-epique.fr site.

  The import is idempotent: every row keeps its Firebase key (`legacy_key`, or
  the author uid for reviews) and existing rows are updated instead of
  duplicated.

  Firebase nodes:

    * `aires_enrichies` – the playgrounds shown on the map
    * `nouvelle_aire` – author and date of the playgrounds added by visitors
    * `aires_infos` – details, one entry per edit (the site showed the latest)
    * `comments` – reviews, one per author
    * `images` – photo URLs (replaced by local files in a later step)
    * `aires_suppression` – removal reports
    * `aires` – raw OSM data, only used to report playgrounds missing from the map
    * `geofire` – ignored, replaced by PostGIS
  """

  import Ecto.Query

  alias ParcEpique.Playgrounds.{Detail, Equipment, Photo, Playground, RemovalReport, Review}
  alias ParcEpique.Repo

  @chunk_size 1000

  @doc """
  Imports the export at `path` and returns a report map.
  """
  def run(path) do
    path |> File.read!() |> Jason.decode!() |> import_data()
  end

  @doc false
  def import_data(data) do
    now = DateTime.utc_now(:second)

    Repo.transaction(
      fn ->
        playgrounds = import_playgrounds(data, now)
        ids = playground_ids()

        %{
          playgrounds: playgrounds,
          details: import_details(data, ids, now),
          reviews: import_reviews(data, ids, now),
          photos: import_photos(data, ids, now),
          removal_reports: import_removal_reports(data, ids, now),
          raw_osm_not_on_map: raw_osm_not_on_map(data)
        }
      end,
      timeout: :infinity
    )
  end

  defp import_playgrounds(data, now) do
    added = Map.get(data, "nouvelle_aire", %{})

    {rows, skipped} =
      data
      |> Map.get("aires_enrichies", %{})
      |> Enum.reduce({[], []}, fn {key, area}, {rows, skipped} ->
        case playground_row(key, area, Map.get(added, key), now) do
          {:ok, row} -> {[row | rows], skipped}
          :error -> {rows, [key | skipped]}
        end
      end)

    upsert(Playground, rows, :legacy_key, [:osm_type, :osm_id, :location, :name, :source])

    %{imported: length(rows), skipped: Enum.sort(skipped)}
  end

  defp playground_row(key, %{"lat" => lat, "lon" => lon} = area, added, now)
       when is_number(lat) and is_number(lon) do
    {osm_type, osm_id} = parse_osm_key(key)
    added = added || %{}

    {:ok,
     %{
       legacy_key: key,
       osm_type: osm_type,
       osm_id: osm_id,
       location: Playground.point(lat * 1.0, lon * 1.0),
       name: blank_to_nil(area["name"]),
       source: if(osm_type, do: "osm", else: "user"),
       status: "visible",
       legacy_author_uid: added["uid"],
       inserted_at: from_timestamp(added["timestamp"]) || now,
       updated_at: now
     }}
  end

  defp playground_row(_key, _area, _added, _now), do: :error

  @doc false
  def parse_osm_key(key) do
    with [type, id] when type in ~w(node way relation) <- String.split(key, "-", parts: 2),
         {id, ""} <- Integer.parse(id) do
      {type, id}
    else
      _ -> {nil, nil}
    end
  end

  defp import_details(data, ids, now) do
    {rows, report} =
      data
      |> Map.get("aires_infos", %{})
      |> flat_children()
      |> Enum.reduce({[], %{orphans: 0, unknown_equipment: MapSet.new()}}, fn
        {area_key, push_id, info}, {rows, report} ->
          case Map.fetch(ids, area_key) do
            {:ok, playground_id} ->
              {equipment, unknown} = equipment_codes(info["equipements"])

              row = %{
                playground_id: playground_id,
                legacy_key: push_id,
                equipment: equipment,
                free: info["gratuit"],
                open_at_night: info["ouvertNuit"],
                private: info["prive"],
                # The old site displayed every entry without moderation.
                status: "validated",
                legacy_author_uid: info["uid"],
                inserted_at: from_timestamp(info["timestamp"]) || now,
                updated_at: now
              }

              {[row | rows],
               %{report | unknown_equipment: MapSet.union(report.unknown_equipment, unknown)}}

            :error ->
              {rows, %{report | orphans: report.orphans + 1}}
          end
      end)

    upsert(Detail, rows, :legacy_key, [:equipment, :free, :open_at_night, :private])

    %{
      imported: length(rows),
      orphans: report.orphans,
      unknown_equipment: report.unknown_equipment |> MapSet.to_list() |> Enum.sort()
    }
  end

  defp equipment_codes(labels) when is_list(labels) do
    Enum.reduce(labels, {[], MapSet.new()}, fn label, {codes, unknown} ->
      case Equipment.from_legacy_label(label) do
        {:ok, code} -> {Enum.uniq(codes ++ [code]), unknown}
        :error -> {codes, MapSet.put(unknown, label)}
      end
    end)
  end

  defp equipment_codes(_), do: {[], MapSet.new()}

  defp import_reviews(data, ids, now) do
    {rows, orphans} =
      data
      |> Map.get("comments", %{})
      |> flat_children()
      |> Enum.reduce({[], 0}, fn {area_key, uid, review}, {rows, orphans} ->
        case Map.fetch(ids, area_key) do
          {:ok, playground_id} ->
            row = %{
              playground_id: playground_id,
              legacy_author_uid: uid,
              rating_surroundings: to_float(review["ratingSurroundings"]),
              rating_equipment: to_float(review["ratingEquipment"]),
              comment: blank_to_nil(review["comment"]),
              display_name: blank_to_nil(review["displayName"]),
              inserted_at: from_timestamp(review["timestamp"]) || now,
              updated_at: now
            }

            {[row | rows], orphans}

          :error ->
            {rows, orphans + 1}
        end
      end)

    upsert(Review, rows, [:playground_id, :legacy_author_uid], [
      :rating_surroundings,
      :rating_equipment,
      :comment,
      :display_name
    ])

    %{imported: length(rows), orphans: orphans}
  end

  defp import_photos(data, ids, now) do
    {rows, orphans} =
      data
      |> Map.get("images", %{})
      |> flat_children()
      |> Enum.reduce({[], 0}, fn {area_key, picture_id, image}, {rows, orphans} ->
        with {:ok, playground_id} <- Map.fetch(ids, area_key),
             path when is_binary(path) <- image["path"] do
          row = %{
            playground_id: playground_id,
            legacy_key: "#{area_key}/#{picture_id}",
            path: path,
            thumbnail_path: image["thumbnail"],
            verified: image["verified"] == true,
            legacy_author_uid: image["uid"],
            inserted_at: now,
            updated_at: now
          }

          {[row | rows], orphans}
        else
          _ -> {rows, orphans + 1}
        end
      end)

    # Keep paths that a later photo import may have replaced with local files.
    upsert(Photo, rows, :legacy_key, [:verified])

    %{imported: length(rows), orphans: orphans}
  end

  defp import_removal_reports(data, ids, now) do
    {rows, orphans} =
      data
      |> Map.get("aires_suppression", %{})
      |> Enum.reduce({[], 0}, fn {area_key, report}, {rows, orphans} ->
        case Map.fetch(ids, area_key) do
          {:ok, playground_id} when is_map(report) ->
            row = %{
              playground_id: playground_id,
              legacy_key: area_key,
              reason: blank_to_nil(report["raison"]),
              status: "pending",
              legacy_author_uid: report["uid"],
              inserted_at: from_timestamp(report["timestamp"]) || now,
              updated_at: now
            }

            {[row | rows], orphans}

          _ ->
            {rows, orphans + 1}
        end
      end)

    upsert(RemovalReport, rows, :legacy_key, [:reason])

    %{imported: length(rows), orphans: orphans}
  end

  defp raw_osm_not_on_map(data) do
    on_map = Map.get(data, "aires_enrichies", %{})

    data
    |> Map.get("aires", %{})
    |> Map.keys()
    |> Enum.count(&(not Map.has_key?(on_map, &1)))
  end

  defp playground_ids do
    Playground
    |> where([p], not is_nil(p.legacy_key))
    |> select([p], {p.legacy_key, p.id})
    |> Repo.all()
    |> Map.new()
  end

  # %{"a" => %{"x" => v}} -> [{"a", "x", v}]
  defp flat_children(node) do
    for {parent, children} when is_map(children) <- node,
        {child, value} when is_map(value) <- children,
        do: {parent, child, value}
  end

  defp upsert(_schema, [], _conflict_target, _fields), do: :ok

  defp upsert(schema, rows, conflict_target, fields) do
    rows
    |> Enum.chunk_every(@chunk_size)
    |> Enum.each(fn chunk ->
      Repo.insert_all(schema, chunk,
        on_conflict: {:replace, fields ++ [:updated_at]},
        conflict_target: conflict_target
      )
    end)
  end

  defp from_timestamp(ms) when is_integer(ms) do
    case DateTime.from_unix(ms, :millisecond) do
      {:ok, datetime} -> DateTime.truncate(datetime, :second)
      _ -> nil
    end
  end

  defp from_timestamp(_), do: nil

  defp to_float(n) when is_number(n), do: n * 1.0
  defp to_float(_), do: nil

  defp blank_to_nil(s) when is_binary(s) do
    case String.trim(s) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_), do: nil
end
