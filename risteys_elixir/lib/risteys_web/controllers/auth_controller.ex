defmodule RisteysWeb.AuthController do
  use RisteysWeb, :controller
  alias RisteysWeb.Router.Helpers, as: Routes

  plug Ueberauth

  def set_redir(conn, %{"provider" => provider, "fg_endpoint" => fg_endpoint}) do
    state = %{fg_endpoint: fg_endpoint}
    conn = put_session(conn, :redir_state, state)

    auth = Routes.auth_path(conn, :request, provider)
    Phoenix.Controller.redirect(conn, to: auth)
  end

  # Authentication failed
  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    put_session(conn, :user_is_authz, false)
  end

  def callback(%{assigns: %{ueberauth_auth: %{info: info}}} = conn, _params) do
    if authz?(info) do
      # Keep the authz status
      conn = put_session(conn, :user_is_authz, true)

      # Redirect the user to the endpoint they were on before logging in
      %{fg_endpoint: fg_endpoint} = get_session(conn, :redir_state)
      endpoint = Routes.fg_endpoint_path(conn, :show, fg_endpoint)
      Phoenix.Controller.redirect(conn, to: endpoint)
    else
      # Authorization failed
      put_session(conn, :user_is_authz, false)
    end
  end

  defp authz?(info) do
    %{
      email: email,
      urls: %{website: website}
    } = info

    String.ends_with?(email, "@finngen.fi") # and website == "finregistry.fi" # TODO: find out what is correct condition for authorization. website == "finregistry.fi condition causes HTTP error 500.
  end
end
