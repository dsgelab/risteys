defmodule RisteysWeb.AuthControllerTest do
  use RisteysWeb.ConnCase
  alias RisteysWeb.Router.Helpers, as: Routes

  test "login", %{conn: conn} do
    conn = get(conn, Routes.auth_path(conn, :login))
    assert html_response(conn, 200) =~ "Login using your Finngen Google account"
  end

  test "logout", %{conn: conn} do
    conn = get(conn, Routes.auth_path(conn, :logout))
    assert redirected_to(conn) =~ Routes.home_path(conn, :index)
  end
end
