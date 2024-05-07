defmodule RisteysWeb.AuthController do
  use RisteysWeb, :controller

  plug Ueberauth

  # Remember the page the user was on before logging in
  def set_redir(conn, %{"provider" => provider, "fg_endpoint" => fg_endpoint}) do
    state = %{fg_endpoint: fg_endpoint}
    conn = put_session(conn, :redir_state, state)

    auth = ~p"/auth/#{provider}"
    Phoenix.Controller.redirect(conn, to: auth)
  end

  # Authentication failed
  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    put_session(conn, :user_is_authz, false)
  end

  # Authentication succeeded
  def callback(%{assigns: %{ueberauth_auth: %{info: info}}} = conn, _params) do
    if authz?(info) do
      # Keep the authz status
      conn = put_session(conn, :user_is_authz, true)

      # Redirect the user to the endpoint they were on before logging in
      %{fg_endpoint: fg_endpoint} = get_session(conn, :redir_state)
      endpoint = ~p"/endpoints/#{fg_endpoint}"
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


    (
      String.ends_with?(email, "@finngen.fi")
      # From the ueberauth_google documentation:
      # > To guard against client-side request modification, it's important to
      # > still check the domain in info.urls[:website] within the Ueberauth.Auth
      # > struct if you want to limit sign-in to a specific domain.
      and website == "finngen.fi"
    )
  end

  def delete(conn, _params) do
    conn
    |> clear_session()
    |> redirect(to: ~p"/")
  end
end
