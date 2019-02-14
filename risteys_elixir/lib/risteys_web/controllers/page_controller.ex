defmodule RisteysWeb.PageController do
  use RisteysWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
