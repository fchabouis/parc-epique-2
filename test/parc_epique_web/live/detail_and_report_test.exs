defmodule ParcEpiqueWeb.DetailAndReportTest do
  use ParcEpiqueWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ParcEpique.Playgrounds.{Detail, Playground, RemovalReport}
  alias ParcEpique.Repo

  setup do
    playground =
      Repo.insert!(
        Playground.changeset(%Playground{}, %{
          name: "Square Scipion",
          location: Playground.point(48.8386, 2.3536)
        })
      )

    %{playground: playground}
  end

  test "details are proposed as pending and not shown before validation", %{
    conn: conn,
    playground: p
  } do
    {:ok, view, _html} = live(conn, ~p"/fr/aires/#{p.id}")

    view |> element("#suggest-details") |> render_click()

    html =
      view
      |> form("#detail-form",
        detail: %{
          equipment: ["slide", "sandpit"],
          free: "true",
          open_at_night: "",
          private: "false"
        }
      )
      |> render_submit()

    assert html =~ "sera affichée une fois vérifiée"
    refute has_element?(view, "#detail-form")
    refute html =~ "Toboggan"

    assert [%Detail{status: "pending", equipment: ["slide", "sandpit"], free: true} = detail] =
             Repo.all(Detail)

    assert detail.open_at_night == nil
    assert detail.private == false
    assert detail.user_id

    Repo.update_all(Detail, set: [status: "validated"])
    {:ok, _view, html} = live(conn, ~p"/fr/aires/#{p.id}")
    assert html =~ "Toboggan"
    assert html =~ "Gratuite"
  end

  test "at least one piece of information is required", %{conn: conn, playground: p} do
    {:ok, view, _html} = live(conn, ~p"/fr/aires/#{p.id}")

    view |> element("#suggest-details") |> render_click()

    html =
      view
      |> form("#detail-form", detail: %{free: "", open_at_night: "", private: ""})
      |> render_submit()

    assert html =~ "indiquez au moins une information"
    assert Repo.all(Detail) == []
  end

  test "the details form can be closed", %{conn: conn, playground: p} do
    {:ok, view, _html} = live(conn, ~p"/fr/aires/#{p.id}")
    view |> element("#suggest-details") |> render_click()
    view |> element("#detail-form button", "Annuler") |> render_click()
    refute has_element?(view, "#detail-form")
  end

  test "a removal report asks for confirmation and is recorded once", %{conn: conn, playground: p} do
    {:ok, view, _html} = live(conn, ~p"/fr/aires/#{p.id}")

    view |> element("#report-removal") |> render_click()
    assert has_element?(view, "#report-confirmation")
    assert Repo.all(RemovalReport) == []

    view |> element("#report-confirmation button", "Oui, elle n'existe plus") |> render_click()
    assert render(view) =~ "votre signalement sera vérifié"
    refute has_element?(view, "#report-confirmation")

    assert [%RemovalReport{status: "pending", user_id: user_id}] = Repo.all(RemovalReport)
    assert user_id

    view |> element("#report-removal") |> render_click()
    view |> element("#report-confirmation button", "Oui, elle n'existe plus") |> render_click()
    assert [_one] = Repo.all(RemovalReport)
  end

  test "a report can be cancelled", %{conn: conn, playground: p} do
    {:ok, view, _html} = live(conn, ~p"/fr/aires/#{p.id}")
    view |> element("#report-removal") |> render_click()
    view |> element("#report-confirmation button", "Annuler") |> render_click()
    refute has_element?(view, "#report-confirmation")
    assert Repo.all(RemovalReport) == []
  end
end
