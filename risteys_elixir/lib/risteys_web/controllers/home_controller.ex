defmodule RisteysWeb.HomeController do
  use RisteysWeb, :controller
  plug :put_layout, "minimal.html"

  def index(conn, _params) do
    conn
    |> assign(:user_is_authenticated, get_session(conn, :user_is_authenticated))
    |> render("index.html")
  end
end
