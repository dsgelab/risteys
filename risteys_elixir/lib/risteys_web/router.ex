defmodule RisteysWeb.Router do
  use RisteysWeb, :router

  def authz_user(conn, _opts) do
    if get_session(conn, :user_is_authenticated) do
      conn
    else
      conn
      |> Phoenix.Controller.redirect(to: "/auth/login")
    end
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :browser_authz do
    plug :browser
    plug :authz_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RisteysWeb do
    pipe_through :browser_authz

    get "/", HomeController, :index
    get "/changelog", ChangelogController, :index
    get "/phenocode/:name", PhenocodeController, :show
  end

  scope "/auth", RisteysWeb do
    pipe_through :browser

    get "/logout", AuthController, :logout
    get "/login", AuthController, :login
    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  # Other scopes may use custom stacks.
  # scope "/api", RisteysWeb do
  #   pipe_through :api
  # end
end
