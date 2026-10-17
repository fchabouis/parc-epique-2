defmodule ParcEpiqueWeb.ContributorAuthTest do
  use ParcEpiqueWeb.ConnCase, async: true

  import ParcEpique.AccountsFixtures

  alias ParcEpique.Accounts
  alias ParcEpique.Accounts.Scope
  alias ParcEpique.Playgrounds.{Playground, Review}
  alias ParcEpique.Repo
  alias ParcEpiqueWeb.UserAuth

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, ParcEpiqueWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{conn: conn}
  end

  test "every browser session gets a guest token, kept across requests" do
    conn = get(build_conn(), ~p"/fr")
    assert token = get_session(conn, :guest_token)

    conn = conn |> recycle() |> get(~p"/fr")
    assert get_session(conn, :guest_token) == token
  end

  test "logging in moves the guest's contributions to the account", %{conn: conn} do
    token = Accounts.generate_guest_token()
    guest = Accounts.get_or_create_guest_user(token)

    playground =
      Repo.insert!(Playground.changeset(%Playground{}, %{location: Playground.point(48.8, 2.3)}))

    review = Repo.insert!(%Review{playground_id: playground.id, user_id: guest.id})
    user = user_fixture()

    conn = conn |> put_session(:guest_token, token) |> UserAuth.log_in_user(user)

    assert Repo.reload!(review).user_id == user.id
    refute get_session(conn, :guest_token)
  end

  describe "require_admin/2" do
    test "redirects visitors to log in", %{conn: conn} do
      conn = conn |> fetch_flash() |> assign(:current_scope, nil) |> UserAuth.require_admin([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "redirects users who are not administrators", %{conn: conn} do
      conn =
        conn
        |> fetch_flash()
        |> assign(:current_scope, Scope.for_user(user_fixture()))
        |> UserAuth.require_admin([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end

    test "lets administrators through", %{conn: conn} do
      {:ok, admin} = Accounts.set_admin(user_fixture(), true)

      conn =
        conn
        |> fetch_flash()
        |> assign(:current_scope, Scope.for_user(admin))
        |> UserAuth.require_admin([])

      refute conn.halted
    end
  end

  test "the header links to log in, or to the account", %{conn: conn} do
    assert conn |> get(~p"/fr") |> html_response(200) =~ ~p"/users/log-in"

    user = user_fixture(%{display_name: "Camille"})
    html = conn |> log_in_user(user) |> get(~p"/fr") |> html_response(200)
    assert html =~ "Camille"
    assert html =~ ~p"/users/log-out"
  end
end
