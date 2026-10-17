defmodule ParcEpiqueWeb.ReviewFormTest do
  use ParcEpiqueWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import ParcEpique.AccountsFixtures

  alias ParcEpique.Playgrounds.{Playground, Review}
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

  defp post_review(view, review) do
    view |> element("#write-review") |> render_click()
    view |> form("#review-form", review: review) |> render_submit()
  end

  test "a guest posts a review and is invited to sign up", %{conn: conn, playground: p} do
    {:ok, view, _html} = live(conn, ~p"/fr/aires/#{p.id}")

    html =
      post_review(view, %{rating_surroundings: "4.5", rating_equipment: "3.0", comment: "Ombragé"})

    assert html =~ "Merci pour votre avis !"
    assert html =~ "Ombragé"
    assert html =~ "Anonyme"
    assert html =~ "4,5 sur 5"
    assert has_element?(view, "#register-prompt a[href='/users/register']")
    assert_push_event(view, "reviewed", %{id: id})
    assert id == p.id

    assert [%Review{rating_surroundings: 4.5, rating_equipment: 3.0, user_id: user_id}] =
             Repo.all(Review)

    assert %{email: nil} = Repo.get!(ParcEpique.Accounts.User, user_id)
  end

  test "posting again updates the review", %{conn: conn, playground: p} do
    {:ok, view, _html} = live(conn, ~p"/fr/aires/#{p.id}")

    post_review(view, %{rating_surroundings: "2.0", rating_equipment: "2.0"})

    view |> element("#write-review") |> render_click()
    assert has_element?(view, "#review-form input[value='2.0'][checked]")

    html =
      view
      |> form("#review-form", review: %{rating_surroundings: "5.0", rating_equipment: "4.0"})
      |> render_submit()

    assert [%Review{rating_surroundings: 5.0, rating_equipment: 4.0}] = Repo.all(Review)
    assert html =~ "5,0 sur 5"
  end

  test "a signed-in user's review bears their name", %{conn: conn, playground: p} do
    user = user_fixture(%{display_name: "Camille"})
    {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/fr/aires/#{p.id}")

    html = post_review(view, %{rating_surroundings: "4.0", rating_equipment: "4.0"})

    assert html =~ "Camille, le"
    refute has_element?(view, "#register-prompt")
    assert [%Review{user_id: user_id, display_name: "Camille"}] = Repo.all(Review)
    assert user_id == user.id
  end

  test "both ratings are required", %{conn: conn, playground: p} do
    {:ok, view, _html} = live(conn, ~p"/fr/aires/#{p.id}")

    html = post_review(view, %{comment: "Pas de note"})

    assert html =~ "doit être renseigné"
    assert Repo.all(Review) == []
  end

  test "the form can be closed", %{conn: conn, playground: p} do
    {:ok, view, _html} = live(conn, ~p"/fr/aires/#{p.id}")

    view |> element("#write-review") |> render_click()
    view |> element("#review-form button", "Annuler") |> render_click()
    refute has_element?(view, "#review-form")
  end
end
