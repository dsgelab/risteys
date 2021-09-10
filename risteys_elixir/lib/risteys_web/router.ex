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
    get "/phenocode/:name", PhenocodeController, :show
  end

  scope "/auth", RisteysWeb do
    pipe_through :browser

    get "/:provider/set_redir/:fg_endpoint", AuthController, :set_redir
    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  scope "/api", RisteysWeb do
    pipe_through :api

    get "/phenocode/:name/assocs.json", PhenocodeController, :get_assocs_json
    get "/phenocode/:name/assocs.csv", PhenocodeController, :get_assocs_csv
    get "/phenocode/:name/drugs.json", PhenocodeController, :get_drugs_json
    get "/phenocode/:name/drugs.csv", PhenocodeController, :get_drugs_csv
  end
end
