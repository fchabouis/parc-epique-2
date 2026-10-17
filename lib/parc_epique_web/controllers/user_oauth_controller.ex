defmodule ParcEpiqueWeb.UserOAuthController do
  @moduledoc """
  Sign-in with Google through Ueberauth. The `Ueberauth` plug redirects
  `/auth/google` to Google and fills in `:ueberauth_auth` on the callback.
  """
  use ParcEpiqueWeb, :controller

  alias ParcEpique.Accounts
  alias ParcEpiqueWeb.UserAuth

  plug Ueberauth

  @doc "Whether an OAuth client is configured for Google."
  def google_enabled? do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth, [])
    is_binary(config[:client_id]) and config[:client_id] != ""
  end

  # Only reached for providers Ueberauth does not know.
  def request(conn, _params), do: failure(conn)

  def callback(%{assigns: %{ueberauth_auth: %Ueberauth.Auth{} = auth}} = conn, _params) do
    with email when is_binary(email) <- auth.info.email,
         true <- verified_email?(auth),
         {:ok, user} <- Accounts.get_or_register_verified_user(email) do
      conn
      |> put_flash(:info, gettext("Welcome back!"))
      |> UserAuth.log_in_user(user, %{"remember_me" => "true"})
    else
      _ -> failure(conn)
    end
  end

  def callback(conn, _params), do: failure(conn)

  defp verified_email?(%Ueberauth.Auth{extra: %{raw_info: %{user: user}}}) when is_map(user),
    do: user["email_verified"] in [true, "true"]

  defp verified_email?(_auth), do: false

  defp failure(conn) do
    conn
    |> put_flash(:error, gettext("The sign-in with Google failed."))
    |> redirect(to: ~p"/users/log-in")
  end
end
