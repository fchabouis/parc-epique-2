defmodule ParcEpiqueWeb.PageController do
  use ParcEpiqueWeb, :controller

  def redirect_to_locale(conn, _params) do
    redirect(conn, to: ~p"/#{ParcEpiqueWeb.Plugs.Locale.default_locale()}")
  end

  def about(conn, _params) do
    conn
    |> assign(:page_title, gettext("About"))
    |> assign(:export_date, ParcEpique.Export.generated_at())
    |> render(:about)
  end
end
