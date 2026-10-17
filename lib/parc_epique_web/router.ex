defmodule ParcEpiqueWeb.Router do
  use ParcEpiqueWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ParcEpiqueWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :locale do
    plug ParcEpiqueWeb.Plugs.Locale
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ParcEpiqueWeb do
    pipe_through :browser

    get "/", PageController, :redirect_to_locale
  end

  # Other scopes may use custom stacks.
  # scope "/api", ParcEpiqueWeb do
  #   pipe_through :api
  # end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:parc_epique, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  scope "/:locale", ParcEpiqueWeb do
    pipe_through [:browser, :locale]

    live_session :public, on_mount: ParcEpiqueWeb.LiveLocale do
      live "/", MapLive
    end
  end
end
