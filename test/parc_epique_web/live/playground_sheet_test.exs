defmodule ParcEpiqueWeb.PlaygroundSheetTest do
  use ParcEpiqueWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ParcEpique.Playgrounds.{Detail, Photo, Playground, Review}
  alias ParcEpique.Repo

  defp playground(attrs \\ %{}) do
    Repo.insert!(
      Playground.changeset(
        %Playground{},
        Map.merge(%{location: Playground.point(48.8433, 2.3497)}, attrs)
      )
    )
  end

  test "renders a playground on its own page", %{conn: conn} do
    playground = playground(%{name: "Square Scipion"})

    Repo.insert!(%Review{
      playground_id: playground.id,
      rating_surroundings: 4.0,
      rating_equipment: 3.0,
      comment: "Très ombragé",
      display_name: "Camille",
      inserted_at: ~U[2021-03-12 10:00:00Z]
    })

    Repo.insert!(%Review{playground_id: playground.id, rating_surroundings: 5.0})

    Repo.insert!(%Detail{
      playground_id: playground.id,
      status: "validated",
      equipment: ["slide", "sandpit"],
      free: true,
      open_at_night: false
    })

    Repo.insert!(%Detail{playground_id: playground.id, status: "pending", free: false})

    Repo.insert!(%Photo{
      playground_id: playground.id,
      path: "photos/#{playground.id}/a.jpg",
      thumbnail_path: "photos/#{playground.id}/thumb_a.jpg"
    })

    html = conn |> get(~p"/fr/aires/#{playground.id}") |> html_response(200)

    assert html =~ "Square Scipion"
    assert html =~ "Camille, le 12 mars 2021"
    assert html =~ "Très ombragé"
    assert html =~ "4,5 sur 5"
    assert html =~ "Gratuite"
    assert html =~ "Fermée la nuit"
    refute html =~ "Payante"
    assert html =~ "Toboggan"
    assert html =~ "Bac à sable"
    assert html =~ "/uploads/photos/#{playground.id}/thumb_a.jpg"
    assert html =~ "destination=48.8433%2C2.3497"
    assert html =~ ~s(data-focus-lat="48.8433")
  end

  test "invites to review a playground without ratings", %{conn: conn} do
    playground = playground()

    {:ok, _view, html} = live(conn, ~p"/fr/aires/#{playground.id}")

    assert html =~ "Aire de jeux"
    assert html =~ "Pas encore de note, soyez le premier à rédiger un avis !"
    assert html =~ "La description de cette aire est inconnue pour le moment."
  end

  test "is not found for unknown, hidden or malformed ids", %{conn: conn} do
    hidden = playground(%{status: "hidden"})

    for id <- [hidden.id, hidden.id + 1000, "abc", "1x"] do
      assert_error_sent 404, fn -> get(conn, "/fr/aires/#{id}") end
    end
  end

  test "opens and closes the sheet from the map", %{conn: conn} do
    playground = playground(%{name: "Square Scipion"})

    {:ok, view, html} = live(conn, ~p"/fr")
    refute html =~ "playground-sheet"

    render_hook(view, "open", %{"id" => playground.id})
    assert_patch(view, ~p"/fr/aires/#{playground.id}")
    assert has_element?(view, "#playground-sheet", "Square Scipion")
    assert page_title(view) =~ "Square Scipion"
    assert_push_event(view, "focus", %{id: id, lat: 48.8433, lng: 2.3497})
    assert id == playground.id

    view |> element("#playground-sheet a[aria-label=Fermer]") |> render_click()
    assert_patch(view, ~p"/fr")
    assert_push_event(view, "unfocus", %{})
    refute has_element?(view, "#playground-sheet")
  end

  test "enlarges a photo", %{conn: conn} do
    playground = playground()

    photo =
      Repo.insert!(%Photo{
        playground_id: playground.id,
        path: "photos/#{playground.id}/a.jpg",
        thumbnail_path: "photos/#{playground.id}/thumb_a.jpg"
      })

    {:ok, view, _html} = live(conn, ~p"/fr/aires/#{playground.id}")

    view |> element("#photo-#{photo.id} button") |> render_click()
    assert has_element?(view, ~s(#photo-modal img[src="/uploads/photos/#{playground.id}/a.jpg"]))

    render_keydown(view, "hide_photo", %{"key" => "Escape"})
    refute has_element?(view, "#photo-modal")
  end
end
