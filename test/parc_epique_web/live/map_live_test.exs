defmodule ParcEpiqueWeb.MapLiveTest do
  use ParcEpiqueWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ParcEpique.Playgrounds.{Playground, Review}
  alias ParcEpique.Repo
  alias ParcEpiqueWeb.MapLive

  test "renders the map", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/fr")
    assert html =~ ~s(phx-hook="Map")
    assert html =~ "Afficher ma position"
  end

  test "pushes the playgrounds inside the visible bounds", %{conn: conn} do
    named =
      Repo.insert!(
        Playground.changeset(%Playground{}, %{
          name: "Square du Manège",
          location: Playground.point(50.638265, 3.0809135)
        })
      )

    unnamed =
      Repo.insert!(Playground.changeset(%Playground{}, %{location: Playground.point(50.65, 3.1)}))

    Repo.insert!(Review.changeset(%Review{}, %{playground_id: named.id, rating_equipment: 4}))

    {:ok, view, _html} = live(conn, ~p"/fr")
    render_hook(view, "bounds", %{"south" => 50.6, "west" => 3, "north" => 50.7, "east" => 3.2})

    assert_push_event(view, "playgrounds", %{playgrounds: playgrounds})

    assert Enum.sort_by(playgrounds, & &1.id) == [
             %{
               id: named.id,
               lat: 50.638265,
               lng: 3.0809135,
               name: "Square du Manège",
               reviewed: true
             },
             %{id: unnamed.id, lat: 50.65, lng: 3.1, name: "Aire de jeux", reviewed: false}
           ]
  end

  test "ignores malformed bounds", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/fr")
    render_hook(view, "bounds", %{"south" => "x"})
    refute_push_event(view, "playgrounds", _)
  end

  test "clamps bounds to valid coordinates" do
    assert {:ok, %{south: -90.0, north: 90.0, west: -180.0, east: 180.0}} =
             MapLive.parse_bounds(%{
               "south" => -100,
               "west" => -540,
               "north" => 95,
               "east" => 400
             })
  end
end
