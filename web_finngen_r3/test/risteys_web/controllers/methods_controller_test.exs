defmodule RisteysWeb.MethodsControllerTest do
  use RisteysWeb.ConnCase

  describe "index" do
    test "Display methods page", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, user_is_authenticated: true)
      conn = get(conn, Routes.methods_path(conn, :index))
      assert html_response(conn, 200) =~ "Methods"
    end
  end
end
