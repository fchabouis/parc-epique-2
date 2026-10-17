defmodule ParcEpiqueWeb.ModerationLiveTest do
  use ParcEpiqueWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import ParcEpique.AccountsFixtures

  alias ParcEpique.{Accounts, Playgrounds}
  alias ParcEpique.Playgrounds.Playground
  alias ParcEpique.Repo

  setup do
    playground =
      Repo.insert!(
        Playground.changeset(%Playground{}, %{
          name: "Square Scipion",
          location: Playground.point(48.8386, 2.3536)
        })
      )

    %{playground: playground, visitor: user_fixture()}
  end

  describe "access" do
    test "visitors are sent to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/fr/admin")
    end

    test "users who are not administrators are sent home", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/fr/admin")
    end

    test "the moderation link is shown to administrators only", %{conn: conn} do
      html = conn |> log_in_user(user_fixture()) |> get(~p"/fr") |> html_response(200)
      refute html =~ "/fr/admin"

      html = conn |> log_in_user(admin_fixture()) |> get(~p"/fr") |> html_response(200)
      assert html =~ "/fr/admin"
    end
  end

  describe "as an administrator" do
    setup %{conn: conn} do
      %{conn: log_in_user(conn, admin_fixture())}
    end

    test "says when there is nothing to do", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/fr/admin/details")

      assert html =~ "Modération"
      assert has_element?(view, "#nothing-to-moderate")
    end

    test "new playgrounds are kept or hidden", %{conn: conn, visitor: visitor} do
      {:ok, kept} = Playgrounds.add_playground(visitor, 48.85, 2.35)
      {:ok, hidden} = Playgrounds.add_playground(visitor, 48.86, 2.36)

      {:ok, view, _html} = live(conn, ~p"/fr/admin/aires")
      assert has_element?(view, "#tab-playgrounds .badge", "2")

      view |> element("#playground-#{kept.id} button", "Garder") |> render_click()
      view |> element("#playground-#{hidden.id} button", "Masquer") |> render_click()

      assert has_element?(view, "#nothing-to-moderate")
      assert Repo.reload!(kept).status == "visible"
      assert Repo.reload!(hidden).status == "hidden"
    end

    test "details are validated or rejected", %{conn: conn, playground: p, visitor: visitor} do
      {:ok, one} = Playgrounds.propose_details(p, visitor, %{"equipment" => ["slide"]})
      {:ok, two} = Playgrounds.propose_details(p, visitor, %{"free" => "true"})

      {:ok, view, html} = live(conn, ~p"/fr/admin/details")
      assert html =~ "Toboggan"

      view |> element("#detail-#{one.id} button", "Valider") |> render_click()
      view |> element("#detail-#{two.id} button", "Rejeter") |> render_click()

      assert has_element?(view, "#nothing-to-moderate")
      assert Repo.reload!(one).status == "validated"
      assert Repo.reload!(two).status == "rejected"
    end

    test "a report hides the playground", %{conn: conn, playground: p, visitor: visitor} do
      {:ok, report} = Playgrounds.report_removal(p, visitor)

      {:ok, view, _html} = live(conn, ~p"/fr/admin/signalements")
      view |> element("#report-#{report.id} button", "Masquer l'aire") |> render_click()

      assert has_element?(view, "#nothing-to-moderate")
      assert Repo.reload!(p).status == "hidden"
    end

    test "a report can be dismissed", %{conn: conn, playground: p, visitor: visitor} do
      {:ok, report} = Playgrounds.report_removal(p, visitor)

      {:ok, view, _html} = live(conn, ~p"/fr/admin/signalements")
      view |> element("#report-#{report.id} button", "Rejeter le signalement") |> render_click()

      assert Repo.reload!(p).status == "visible"
      assert Repo.reload!(report).status == "rejected"
    end

    test "photos are validated", %{conn: conn, playground: p, visitor: visitor} do
      photo =
        Repo.insert!(%ParcEpique.Playgrounds.Photo{
          playground_id: p.id,
          user_id: visitor.id,
          path: "photos/#{p.id}/a.jpg",
          thumbnail_path: "photos/#{p.id}/thumb_a.jpg"
        })

      {:ok, view, html} = live(conn, ~p"/fr/admin/photos")
      assert html =~ "/uploads/photos/#{p.id}/thumb_a.jpg"

      view |> element("#photo-#{photo.id} button", "Valider") |> render_click()

      assert has_element?(view, "#nothing-to-moderate")
      assert Repo.reload!(photo).verified
    end

    test "an abusive review is deleted", %{conn: conn, playground: p, visitor: visitor} do
      {:ok, review} = Playgrounds.save_review(p, visitor, %{"comment" => "buy my stuff"})

      {:ok, view, html} = live(conn, ~p"/fr/admin/avis")
      assert html =~ "buy my stuff"

      view |> element("#review-#{review.id} button", "Supprimer") |> render_click()

      refute render(view) =~ "buy my stuff"
      assert Repo.reload(review) == nil
    end

    test "the feed lists the latest contributions", %{conn: conn, playground: p, visitor: v} do
      {:ok, _} = Playgrounds.save_review(p, v, %{"comment" => "nice"})
      {:ok, _} = Playgrounds.report_removal(p, v)

      {:ok, view, _html} = live(conn, ~p"/fr/admin")

      assert has_element?(view, "#feed li", "Avis")
      assert has_element?(view, "#feed li", "Signalement")
      assert has_element?(view, "#feed a[href='/fr/aires/#{p.id}']")
    end

    test "an item already handled is just dropped from the list", %{
      conn: conn,
      playground: p,
      visitor: visitor
    } do
      {:ok, detail} = Playgrounds.propose_details(p, visitor, %{"free" => "true"})
      {:ok, view, _html} = live(conn, ~p"/fr/admin/details")

      Repo.delete!(detail)
      render_click(view, "moderate", %{"action" => "validate_detail", "id" => "#{detail.id}"})

      assert has_element?(view, "#nothing-to-moderate")
    end
  end

  defp admin_fixture do
    {:ok, admin} = Accounts.set_admin(user_fixture(), true)
    admin
  end
end
