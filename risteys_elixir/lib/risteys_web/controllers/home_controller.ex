defmodule RisteysWeb.HomeController do
  use RisteysWeb, :controller

  plug :put_layout, "minimal.html"

  def index(conn, _params) do
    random_endpoint = Risteys.FGEndpoint.get_random_endpoint()

    conn
    |> assign(:random_endpoint, random_endpoint)
    |> render("index.html")
  end
end
