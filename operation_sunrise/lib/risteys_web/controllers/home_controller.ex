defmodule RisteysWeb.HomeController do
  use RisteysWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> render(:index)
  end
end
