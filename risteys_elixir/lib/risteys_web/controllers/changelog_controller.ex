defmodule RisteysWeb.ChangelogController do
  use RisteysWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Changelogs")
    |> render("index.html")
  end
end
