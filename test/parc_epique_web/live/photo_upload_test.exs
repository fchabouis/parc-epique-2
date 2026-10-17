defmodule ParcEpiqueWeb.PhotoUploadTest do
  # Not async: writes to the shared test storage directory.
  use ParcEpiqueWeb.ConnCase
  use Oban.Testing, repo: ParcEpique.Repo

  import Phoenix.LiveViewTest

  alias ParcEpique.Playgrounds.{Photo, Playground}
  alias ParcEpique.{Repo, Storage}
  alias ParcEpique.Workers.GenerateThumbnail

  setup do
    File.rm_rf!(Storage.root())

    playground =
      Repo.insert!(
        Playground.changeset(%Playground{}, %{
          name: "Square Scipion",
          location: Playground.point(48.8386, 2.3536)
        })
      )

    %{playground: playground}
  end

  defp jpeg, do: Image.write!(Image.new!(800, 600, color: :green), :memory, suffix: ".jpg")

  defp upload(view, name, content, type) do
    view
    |> file_input("#photo-form", :photo, [%{name: name, content: content, type: type}])
    |> render_upload(name)
  end

  test "an uploaded photo is stored, shown, and its thumbnail queued", %{
    conn: conn,
    playground: p
  } do
    {:ok, view, _html} = live(conn, ~p"/fr/aires/#{p.id}")

    upload(view, "playground.jpg", jpeg(), "image/jpeg")

    assert [%Photo{verified: false, thumbnail_path: nil, user_id: user_id} = photo] =
             Repo.all(Photo)

    assert user_id
    assert photo.path =~ ~r{^photos/#{p.id}/[0-9a-f-]+\.jpg$}
    assert Storage.exists?(photo.path)
    assert has_element?(view, "#photo-#{photo.id}")
    assert render(view) =~ "Merci pour votre photo"
    assert_enqueued(worker: GenerateThumbnail, args: %{photo_id: photo.id})

    # Until the thumbnail exists, the sheet shows the photo itself.
    assert has_element?(view, ~s(#photo-#{photo.id} img[src="/uploads/#{photo.path}"]))

    assert %{success: 1} = Oban.drain_queue(queue: :media)
    assert Repo.reload!(photo).thumbnail_path
    {:ok, view, _html} = live(conn, ~p"/fr/aires/#{p.id}")
    assert has_element?(view, ~s(#photo-#{photo.id} img[src*="thumb_"]))
  end

  test "a file that is not an image is refused", %{conn: conn, playground: p} do
    {:ok, view, _html} = live(conn, ~p"/fr/aires/#{p.id}")

    upload(view, "playground.jpg", "this is not a jpeg", "image/jpeg")

    assert render(view) =~ "Ce fichier n&#39;est pas une image prise en charge"
    assert Repo.all(Photo) == []
    refute_enqueued(worker: GenerateThumbnail)
  end

  test "other file types are not accepted", %{conn: conn, playground: p} do
    {:ok, view, _html} = live(conn, ~p"/fr/aires/#{p.id}")

    assert {:error, [[_ref, :not_accepted]]} =
             upload(view, "notes.pdf", "%PDF-1.4", "application/pdf")

    assert Repo.all(Photo) == []
  end
end
