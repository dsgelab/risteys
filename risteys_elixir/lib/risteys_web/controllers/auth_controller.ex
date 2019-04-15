defmodule RisteysWeb.AuthController do
  use RisteysWeb, :controller
  alias RisteysWeb.Router.Helpers, as: Routes
  plug Ueberauth
  plug :put_layout, "minimal.html"

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    home = Routes.home_path(conn, :index)

    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: home)
  end

  def callback(%{assigns: %{ueberauth_auth: %{info: %{email: email}}}} = conn, _params) do
    home = Routes.home_path(conn, :index)
    login = Routes.auth_path(conn, :login)

    # TODO check if user is a member of the Finngen group.
    if String.ends_with?(email, "@finngen.fi") do
      conn
      |> put_flash(:info, "Successfully authenticated.")
      |> put_session(:user_is_authenticated, true)
      |> redirect(to: home)
    else
      conn
      |> put_flash(:error, "Could not authenticate: not a Finngen member.")
      |> redirect(to: login)
    end
  end

  def logout(conn, _params) do
    login = Routes.auth_path(conn, :login)

    conn
    |> clear_session()
    |> put_flash(:info, "You have been logged out.")
    |> redirect(to: login)
  end

  def login(conn, _params) do
    conn
    |> render("login.html")
  end
end
