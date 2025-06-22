defmodule PhoenixApp0625Web.Router do
  use PhoenixApp0625Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhoenixApp0625Web.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PhoenixApp0625Web do
    pipe_through :browser

    get "/", PageController, :home
    live "/trains", TrainMapLive, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", PhoenixApp0625Web do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:phoenix_app_06_25, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router
    import Oban.Web.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PhoenixApp0625Web.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
      oban_dashboard "/oban"
    end
  end
end
