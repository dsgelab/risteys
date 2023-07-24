defmodule RisteysWeb.DocumentationController do
  use RisteysWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Documentation")
    |> render(:index)
  end
end
