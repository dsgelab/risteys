defmodule RisteysWeb.HomeController do
  use RisteysWeb, :controller

  plug :put_layout, "minimal.html"

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
