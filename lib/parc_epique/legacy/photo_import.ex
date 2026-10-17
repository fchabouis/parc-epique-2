defmodule ParcEpique.Legacy.PhotoImport do
  @moduledoc """
  Copies the photos exported from Firebase Storage into `ParcEpique.Storage`.

  `ParcEpique.Legacy.FirebaseImport` creates the photo rows with their
  Firebase URLs. This step finds each file in the export by name (Firebase
  named them `{area}_{uid}_{id}`, thumbnails `thumb_{area}_{uid}_{id}`),
  copies it to `photos/<playground id>/`, regenerates a missing thumbnail and
  replaces the URLs with storage keys. Photos already imported are skipped,
  so it can be re-run.

  Unfinished downloads (`*.gstmp`) are ignored and listed in the report:
  download them again (`gcloud storage rsync` resumes) and re-run.
  """

  import Ecto.Query

  alias ParcEpique.{Media, Repo, Storage}
  alias ParcEpique.Playgrounds.Photo

  @doc """
  Imports the photos found under `export_dir` and returns a report map.
  """
  def run(export_dir) do
    {partial, files} = export_dir |> list_files() |> Enum.split_with(&partial_download?/1)
    files = Map.new(files, &{Path.basename(&1), &1})

    photos = Repo.all(from p in Photo, where: like(p.path, "http%"), order_by: p.id)

    results = Enum.map(photos, &import_photo(&1, files))
    used = for {:ok, names, _} <- results, name <- names, into: MapSet.new(), do: name

    %{
      imported: Enum.count(results, &match?({:ok, _, _}, &1)),
      thumbnails_generated: Enum.count(results, &match?({:ok, _, true}, &1)),
      missing: for({:missing, legacy_key} <- results, do: legacy_key),
      failed: for({:failed, legacy_key, reason} <- results, do: {legacy_key, reason}),
      unused_files: files |> Map.keys() |> Enum.reject(&(&1 in used)) |> Enum.sort(),
      partial_downloads: partial |> Enum.map(&Path.basename/1) |> Enum.sort()
    }
  end

  defp import_photo(photo, files) do
    name = file_name(photo.path)
    thumbnail_name = if photo.thumbnail_path, do: file_name(photo.thumbnail_path)

    with {:ok, source} <- Map.fetch(files, name),
         dir = "photos/#{photo.playground_id}",
         key = "#{dir}/#{Path.rootname(name)}#{Media.extension(source) || Path.extname(name)}",
         :ok <- Storage.put_file(source, key),
         {:ok, thumbnail_key, generated?} <-
           put_thumbnail(source, Map.get(files, thumbnail_name || "thumb_" <> name), dir, name) do
      photo
      |> Ecto.Changeset.change(path: key, thumbnail_path: thumbnail_key)
      |> Repo.update!()

      used = if generated?, do: [name], else: [name, thumbnail_name || "thumb_" <> name]
      {:ok, used, generated?}
    else
      :error -> {:missing, photo.legacy_key}
      {:error, reason} -> {:failed, photo.legacy_key, reason}
    end
  end

  # Copies the exported thumbnail, or generates one when it is missing.
  defp put_thumbnail(source, nil, dir, name) do
    key = "#{dir}/thumb_#{Path.rootname(name)}.jpg"

    with :ok <- Media.write_thumbnail(source, Storage.path(key)) do
      {:ok, key, true}
    end
  end

  defp put_thumbnail(_source, thumbnail, dir, name) do
    key = "#{dir}/thumb_#{Path.rootname(name)}#{Media.extension(thumbnail) || ".jpg"}"

    with :ok <- Storage.put_file(thumbnail, key) do
      {:ok, key, false}
    end
  end

  @doc false
  # Firebase public URLs end with the object name, sometimes URL-encoded
  # (`photos%2Farea%2Ffile`).
  def file_name(url) do
    url |> URI.parse() |> Map.get(:path, "") |> URI.decode() |> Path.basename()
  end

  defp list_files(dir) do
    dir
    |> Path.join("**")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
  end

  # gsutil / gcloud leave `.gstmp` files for downloads that did not finish.
  defp partial_download?(path), do: String.ends_with?(path, ".gstmp")
end
