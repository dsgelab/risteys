defmodule RisteysWeb.Router do
  use RisteysWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["csv", "json"]
  end

  scope "/", RisteysWeb do
    pipe_through :browser

    get "/", HomeController, :index
    get "/documentation", DocumentationController, :index
    get "/changelog", ChangelogController, :index
    get "/endpoints/:name", FGEndpointController, :show
    get "/random_endpoint/", FGEndpointController, :redir_random

    # Redirect legacy URLs to keep shared and published links working
    get "/phenocode/:name", FGEndpointController, :redirect_legacy_url
    get "/endpoint/:name", FGEndpointController, :redirect_legacy_url
  end

  scope "/auth", RisteysWeb do
    pipe_through :browser

    get "/:provider/set_redir/:fg_endpoint", AuthController, :set_redir
    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  scope "/api", RisteysWeb do
    pipe_through :api

    get "/endpoints/:name/assocs.json", FGEndpointController, :get_assocs_json
    get "/endpoints/:name/assocs.csv", FGEndpointController, :get_assocs_csv
    get "/endpoints/:name/drugs.json", FGEndpointController, :get_drugs_json
    get "/endpoints/:name/drugs.csv", FGEndpointController, :get_drugs_csv
  end
end
