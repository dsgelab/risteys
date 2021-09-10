defmodule RisteysWeb.AuthController do
  use RisteysWeb, :controller
  alias RisteysWeb.Router.Helpers, as: Routes

  plug Ueberauth

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    # TODO what to do when fails
    IO.inspect(">>>> AUTHN FAILED")

    conn
  end

  def callback(%{assigns: %{ueberauth_auth: %{info: info}}} = conn, _params) do
    if authz?(info) do
      # Redirect the user to the endpoint they were on before logging in
      %{fg_endpoint: fg_endpoint} = get_session(conn, :redir_state)
      pheno = Routes.phenocode_path(conn, :show, fg_endpoint)
      Phoenix.Controller.redirect(conn, to: pheno)
    else
      IO.puts("--- NOPE")
      conn
    end
  end

  defp authz?(info) do
    %{
      email: email,
      urls: %{website: website}
    } = info
    String.ends_with?(email, "@finngen.fi") and website == "finngen.fi"
  end
end
