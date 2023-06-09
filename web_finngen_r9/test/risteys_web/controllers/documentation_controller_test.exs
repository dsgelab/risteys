defmodule RisteysWeb.DocumentationControllerTest do
  use RisteysWeb.ConnCase

  describe "index" do
    test "Display documentation page", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, user_is_authenticated: true)
      conn = get(conn, Routes.documentation_path(conn, :index))
      assert html_response(conn, 200) =~ "Documentation"
    end
  end
end
