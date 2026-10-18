defmodule ParcEpique.Workers.GenerateThumbnailTest do
  # Not async: writes to the shared test storage directory.
  use ParcEpique.DataCase
  use Oban.Testing, repo: ParcEpique.Repo

  alias ParcEpique.Playgrounds.{Photo, Playground}
  alias ParcEpique.Storage
  alias ParcEpique.Workers.GenerateThumbnail

  setup do
    File.rm_rf!(Storage.root())

    playground =
      Repo.insert!(Playground.changeset(%Playground{}, %{location: Playground.point(48.8, 2.3)}))

    key = "photos/#{playground.id}/original.png"
    File.mkdir_p!(Path.dirname(Storage.path(key)))
    Image.write!(Image.new!(1200, 900, color: :green), Storage.path(key))

    photo = Repo.insert!(%Photo{playground_id: playground.id, path: key})
    %{photo: photo}
  end

  test "writes a 400px JPEG thumbnail and records it", %{photo: photo} do
    assert :ok = perform_job(GenerateThumbnail, %{photo_id: photo.id})

    photo = Repo.reload!(photo)

    assert photo.thumbnail_path ==
             String.replace(photo.path, "original.png", "thumb_original.jpg")

    thumbnail = Image.open!(Storage.path(photo.thumbnail_path))
    assert {Image.width(thumbnail), Image.height(thumbnail)} == {400, 300}
  end

  test "does nothing twice", %{photo: photo} do
    assert :ok = perform_job(GenerateThumbnail, %{photo_id: photo.id})
    thumbnail_path = Repo.reload!(photo).thumbnail_path
    assert :ok = perform_job(GenerateThumbnail, %{photo_id: photo.id})
    assert Repo.reload!(photo).thumbnail_path == thumbnail_path
  end

  test "ignores a photo that no longer exists" do
    assert :ok = perform_job(GenerateThumbnail, %{photo_id: 0})
  end

  test "enqueue/1 queues the job on the media queue", %{photo: photo} do
    {:ok, _job} = GenerateThumbnail.enqueue(photo)
    assert_enqueued(worker: GenerateThumbnail, queue: "media", args: %{photo_id: photo.id})
  end
end
