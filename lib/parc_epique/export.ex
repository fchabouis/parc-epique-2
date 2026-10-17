defmodule ParcEpique.Export do
  @moduledoc """
  The public export of the playground database, as GeoJSON.

  The playgrounds come from OpenStreetMap, so the database derived from them
  is shared under the same licence, the ODbL. The export holds what the site
  knows about each visible playground: position, name, validated details and
  the average ratings. It holds nothing about the people who contributed (no
  e-mail, no user id, no review text or author).
  """

  import Ecto.Query

  alias ParcEpique.Playgrounds.{Detail, Playground, Review}
  alias ParcEpique.{Repo, Storage}

  @key "exports/aires.geojson"
  @licence "ODbL-1.0"
  @attribution "© OpenStreetMap contributors, © Parc Épique contributors"

  @doc "The storage key of the export file."
  def key, do: @key

  @doc "When the export was last generated, or `nil` if it never was."
  def generated_at do
    case File.stat(Storage.path(@key), time: :posix) do
      {:ok, %File.Stat{mtime: mtime}} -> DateTime.from_unix!(mtime)
      {:error, _reason} -> nil
    end
  end

  @doc """
  Writes the export to storage, replacing the previous one only once the new
  one is complete. Returns `{:ok, count}`, the number of playgrounds.
  """
  def generate do
    path = Storage.path(@key)
    temporary = path <> ".tmp"
    File.mkdir_p!(Path.dirname(path))

    result =
      Repo.transaction(
        fn ->
          File.open!(temporary, [:write, :utf8], fn file ->
            write(file, query() |> Repo.stream(max_rows: 1000))
          end)
        end,
        timeout: :infinity
      )

    case result do
      {:ok, count} ->
        File.rename!(temporary, path)
        {:ok, count}

      {:error, reason} ->
        File.rm(temporary)
        {:error, reason}
    end
  end

  defp write(file, rows) do
    header =
      Jason.encode!(%{type: "FeatureCollection", license: @licence, attribution: @attribution})

    # Keep the header's closing brace for the end, after the features.
    IO.write(file, String.trim_trailing(header, "}") <> ~s(,"features":[))

    count =
      rows
      |> Stream.map(&(&1 |> feature() |> Jason.encode!()))
      |> Stream.with_index()
      |> Enum.reduce(0, fn {json, index}, _count ->
        IO.write(file, [if(index > 0, do: ",\n", else: "\n"), json])
        index + 1
      end)

    IO.write(file, "\n]}\n")
    count
  end

  defp query do
    ratings =
      from(r in Review,
        group_by: r.playground_id,
        select: %{
          playground_id: r.playground_id,
          reviews: count(r.id),
          surroundings: avg(r.rating_surroundings),
          equipment: avg(r.rating_equipment)
        }
      )

    details =
      from(d in Detail,
        where: d.status == "validated",
        distinct: d.playground_id,
        order_by: [asc: d.playground_id, desc: d.inserted_at, desc: d.id],
        select: %{
          playground_id: d.playground_id,
          equipment: d.equipment,
          free: d.free,
          open_at_night: d.open_at_night,
          private: d.private
        }
      )

    from(p in Playground,
      where: p.status == "visible",
      left_join: r in subquery(ratings),
      on: r.playground_id == p.id,
      left_join: d in subquery(details),
      on: d.playground_id == p.id,
      order_by: p.id,
      select: %{
        id: p.id,
        name: p.name,
        osm_type: p.osm_type,
        osm_id: p.osm_id,
        source: p.source,
        lon: fragment("ST_X(?)", p.location),
        lat: fragment("ST_Y(?)", p.location),
        reviews: coalesce(r.reviews, 0),
        rating_surroundings: r.surroundings,
        rating_equipment: r.equipment,
        equipment: d.equipment,
        free: d.free,
        open_at_night: d.open_at_night,
        private: d.private
      }
    )
  end

  @doc false
  def feature(row) do
    properties =
      %{
        id: row.id,
        name: row.name,
        osm: osm(row),
        source: row.source,
        reviews: row.reviews,
        rating_surroundings: round_rating(row.rating_surroundings),
        rating_equipment: round_rating(row.rating_equipment),
        equipment: row.equipment,
        free: row.free,
        open_at_night: row.open_at_night,
        private: row.private
      }
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    %{
      type: "Feature",
      id: row.id,
      geometry: %{type: "Point", coordinates: [row.lon, row.lat]},
      properties: properties
    }
  end

  defp osm(%{osm_type: type, osm_id: id}) when is_binary(type) and is_integer(id),
    do: "#{type}/#{id}"

  defp osm(_row), do: nil

  defp round_rating(nil), do: nil
  defp round_rating(%Decimal{} = value), do: value |> Decimal.to_float() |> round_rating()
  defp round_rating(value), do: Float.round(value, 2)
end
