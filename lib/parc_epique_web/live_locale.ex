defmodule ParcEpiqueWeb.LiveLocale do
  @moduledoc """
  Sets the Gettext locale of a LiveView process from the `:locale` path
  segment, like `ParcEpiqueWeb.Plugs.Locale` does for plain requests.
  """
  import Phoenix.Component, only: [assign: 3]

  def on_mount(:default, %{"locale" => locale}, _session, socket) do
    if locale in Gettext.known_locales(ParcEpiqueWeb.Gettext) do
      Gettext.put_locale(ParcEpiqueWeb.Gettext, locale)
      {:cont, assign(socket, :locale, locale)}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end
end
