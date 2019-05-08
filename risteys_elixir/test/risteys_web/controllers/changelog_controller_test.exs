defmodule RisteysWeb.ChangelogControllerTest do
  use RisteysWeb.ConnCase

  describe "index" do
    test "lists all changelogs", %{conn: conn} do
      conn = Plug.Test.init_test_session(conn, user_is_authenticated: true)
      conn = get(conn, Routes.changelog_path(conn, :index))
      assert html_response(conn, 200) =~ "Changelogs"
    end
  end
end
