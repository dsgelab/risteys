defmodule RisteysWeb.ChangelogController do
  use RisteysWeb, :controller

  def index(conn, _params) do
    conn
    |> assign(:page_title, "Changelog")
    |> render(:index)
  end
end
