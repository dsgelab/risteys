defmodule RisteysWeb.CodeController do
  use RisteysWeb, :controller

  def show(conn, %{"code" => code}) do
    render(conn, "show.html", code: code)
  end
end
