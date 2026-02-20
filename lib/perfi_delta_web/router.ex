defmodule PerfiDeltaWeb.Router do
  use PerfiDeltaWeb, :router

  import PerfiDeltaWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PerfiDeltaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PerfiDeltaWeb do
    pipe_through :browser

    # Landing page para usuarios no autenticados
    get "/", PageController, :redirect_to_landing
    get "/landing", PageController, :home
  end

  scope "/", PerfiDeltaWeb do
    pipe_through :api
    get "/health", HealthCheckController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", PerfiDeltaWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:perfi_delta, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PerfiDeltaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", PerfiDeltaWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{PerfiDeltaWeb.UserAuth, :require_authenticated}],
      layout: {PerfiDeltaWeb.Layouts, :app} do
      # App principal
      live "/dashboard", DashboardLive, :index
      live "/cuentas", AccountsLive, :index
      live "/cierre", ClosureWizardLive, :index
      live "/historial", HistoryLive, :index
      live "/perfil", ProfileLive, :index

      # Settings
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    live_session :onboarding,
      on_mount: [{PerfiDeltaWeb.UserAuth, :require_authenticated}],
      layout: {PerfiDeltaWeb.Layouts, :onboarding} do
      live "/onboarding", OnboardingLive, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", PerfiDeltaWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{PerfiDeltaWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
      live "/users/resend-confirmation", UserLive.ResendConfirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
