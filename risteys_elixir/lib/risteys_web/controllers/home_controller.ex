defmodule RisteysWeb.HomeController do
  use RisteysWeb, :controller

  def redir(conn, _params) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(external: "https://risteys.finregistry.fi")
  end
end
