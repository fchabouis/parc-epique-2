defmodule ParcEpiqueWeb.Plugs.Locale do
  @moduledoc """
  Sets the Gettext locale from the `:locale` path segment (`/fr/...`).

  Unknown locales get a 404.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{path_params: %{"locale" => locale}} = conn, _opts) do
    if locale in Gettext.known_locales(ParcEpiqueWeb.Gettext) do
      Gettext.put_locale(ParcEpiqueWeb.Gettext, locale)
      assign(conn, :locale, locale)
    else
      conn
      |> put_status(:not_found)
      |> Phoenix.Controller.put_view(html: ParcEpiqueWeb.ErrorHTML)
      |> Phoenix.Controller.render(:"404")
      |> halt()
    end
  end

  def default_locale do
    Gettext.get_locale(ParcEpiqueWeb.Gettext)
  end
end
