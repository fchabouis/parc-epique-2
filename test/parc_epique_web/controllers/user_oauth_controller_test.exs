defmodule ParcEpiqueWeb.UserOAuthControllerTest do
  use ParcEpiqueWeb.ConnCase, async: true

  import ParcEpique.AccountsFixtures

  alias ParcEpique.Accounts
  alias ParcEpiqueWeb.UserOAuthController

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, ParcEpiqueWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})
      |> fetch_flash()

    %{conn: conn}
  end

  defp google_auth(email, verified) do
    %Ueberauth.Auth{
      provider: :google,
      info: %Ueberauth.Auth.Info{email: email},
      extra: %Ueberauth.Auth.Extra{
        raw_info: %{user: %{"email" => email, "email_verified" => verified}}
      }
    }
  end

  test "logs in with a verified Google email, registering the account", %{conn: conn} do
    conn =
      conn
      |> assign(:ueberauth_auth, google_auth("camille@example.com", true))
      |> UserOAuthController.callback(%{})

    assert get_session(conn, :user_token)
    assert redirected_to(conn) == ~p"/"
    assert Accounts.get_user_by_email("camille@example.com").confirmed_at
  end

  test "logs in to an existing account", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> assign(:ueberauth_auth, google_auth(user.email, true))
      |> UserOAuthController.callback(%{})

    assert {%{id: id}, _} = Accounts.get_user_by_session_token(get_session(conn, :user_token))
    assert id == user.id
  end

  test "refuses unverified emails and failures", %{conn: conn} do
    for conn <- [
          conn
          |> assign(:ueberauth_auth, google_auth("camille@example.com", false))
          |> UserOAuthController.callback(%{}),
          conn
          |> assign(:ueberauth_failure, %Ueberauth.Failure{})
          |> UserOAuthController.callback(%{})
        ] do
      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    refute Accounts.get_user_by_email("camille@example.com")
  end

  test "Google is offered on the log in page", %{conn: conn} do
    assert UserOAuthController.google_enabled?()
    assert conn |> get(~p"/users/log-in") |> html_response(200) =~ ~p"/auth/google"
  end
end
