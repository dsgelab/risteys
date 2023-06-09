defmodule RisteysWeb.DocumentationController do
  use RisteysWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html", page_title: "Documentation")
  end
end
