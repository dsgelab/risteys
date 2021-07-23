defmodule RisteysWeb.MethodsController do
  use RisteysWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html", page_title: "Methods")
  end
end
