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
    plug :accepts, ["json"]
  end

  scope "/", RisteysWeb do
    pipe_through :browser

    get "/", HomeController, :index
    get "/methods", MethodsController, :index
    get "/changelog", ChangelogController, :index
    get "/phenocode/:name", PhenocodeController, :show
  end

  scope "/api", RisteysWeb do
    pipe_through :api

    get "/phenocode/:name/assocs.json", PhenocodeController, :get_assocs
  end
end
