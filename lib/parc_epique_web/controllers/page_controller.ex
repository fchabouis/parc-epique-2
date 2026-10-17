defmodule ParcEpiqueWeb.PageController do
  use ParcEpiqueWeb, :controller

  def redirect_to_locale(conn, _params) do
    redirect(conn, to: ~p"/#{ParcEpiqueWeb.Plugs.Locale.default_locale()}")
  end
end
