defmodule ParcEpique.Workers.GenerateThumbnail do
  @moduledoc """
  Generates the thumbnail of an uploaded photo (400x400 at most, orientation
  fixed, metadata removed) and records it on the photo. Replaces the
  `generateThumbnail` Cloud Function of the Firebase version.
  """
  use Oban.Worker, queue: :media, max_attempts: 3

  alias ParcEpique.{Media, Repo, Storage}
  alias ParcEpique.Playgrounds.Photo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"photo_id" => photo_id}}) do
    case Repo.get(Photo, photo_id) do
      nil ->
        # The photo was deleted before its thumbnail was made.
        :ok

      %Photo{thumbnail_path: thumbnail_path} when is_binary(thumbnail_path) ->
        :ok

      %Photo{path: path} = photo ->
        thumbnail_path = thumbnail_key(path)

        with :ok <- Media.write_thumbnail(Storage.path(path), Storage.path(thumbnail_path)),
             {:ok, _photo} <-
               photo |> Ecto.Changeset.change(thumbnail_path: thumbnail_path) |> Repo.update() do
          :ok
        end
    end
  end

  @doc "Enqueues the thumbnail of `photo`."
  def enqueue(%Photo{id: id}), do: %{photo_id: id} |> new() |> Oban.insert()

  # photos/42/abc.png -> photos/42/thumb_abc.jpg
  defp thumbnail_key(path) do
    Path.join(Path.dirname(path), "thumb_" <> Path.rootname(Path.basename(path)) <> ".jpg")
  end
end
