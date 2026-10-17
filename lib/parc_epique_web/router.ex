defmodule ParcEpiqueWeb.Router do
  use ParcEpiqueWeb, :router

  import ParcEpiqueWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ParcEpiqueWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug :fetch_guest_token
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

  ## Authentication routes

  scope "/", ParcEpiqueWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{ParcEpiqueWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post("/users/update-password", UserSessionController, :update_password)
  end

  scope "/", ParcEpiqueWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{ParcEpiqueWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post("/users/log-in", UserSessionController, :create)
    delete("/users/log-out", UserSessionController, :delete)
  end

  # The public export of the database (ODbL), without session or locale
  scope "/", ParcEpiqueWeb do
    get "/export/aires.geojson", ExportController, :geojson
  end

  # Sign-in with Google (Ueberauth)
  scope "/auth", ParcEpiqueWeb do
    pipe_through [:browser]

    get "/:provider", UserOAuthController, :request
    get "/:provider/callback", UserOAuthController, :callback
  end

  # Last, as "/:locale" would match any other first segment.
  scope "/:locale", ParcEpiqueWeb do
    pipe_through [:browser, :locale]

    get "/a-propos", PageController, :about

    live_session :public,
      on_mount: [ParcEpiqueWeb.LiveLocale, {ParcEpiqueWeb.UserAuth, :mount_current_scope}] do
      live "/", MapLive
      live "/aires/:id", MapLive
    end

    live_session :admin,
      on_mount: [ParcEpiqueWeb.LiveLocale, {ParcEpiqueWeb.UserAuth, :require_admin}] do
      live "/admin", AdminLive.Moderation, :feed
      live "/admin/aires", AdminLive.Moderation, :playgrounds
      live "/admin/details", AdminLive.Moderation, :details
      live "/admin/photos", AdminLive.Moderation, :photos
      live "/admin/signalements", AdminLive.Moderation, :reports
      live "/admin/avis", AdminLive.Moderation, :reviews
    end
  end
end
