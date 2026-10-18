defmodule ParcEpiqueWeb.PageController do
  use ParcEpiqueWeb, :controller

  def redirect_to_locale(conn, _params) do
    redirect(conn, to: ~p"/#{ParcEpiqueWeb.Plugs.Locale.default_locale()}")
  end

  def legacy_about(conn, _params) do
    redirect(conn, to: ~p"/#{ParcEpiqueWeb.Plugs.Locale.default_locale()}/a-propos")
  end

  def legacy_login(conn, _params), do: redirect(conn, to: ~p"/users/log-in")

  def about(conn, _params) do
    conn
    |> assign(:page_title, gettext("About"))
    |> assign(:export_date, ParcEpique.Export.generated_at())
    |> render(:about)
  end
end
