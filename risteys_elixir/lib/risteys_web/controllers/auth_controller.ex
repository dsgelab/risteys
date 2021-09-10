defmodule RisteysWeb.AuthController do
  use RisteysWeb, :controller
  plug Ueberauth

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    # TODO what to do when fails
    IO.inspect(">>>> AUTHN FAILED")

    conn
  end

  def callback(%{assigns: %{ueberauth_auth: %{info: info}}} = conn, _params) do
    if authz?(info) do
      IO.puts(">> OK!")
    else
      IO.puts("--- NOPE")
    end

    conn
  end

  defp authz?(info) do
    %{
      email: email,
      urls: %{website: website}
    } = info
    String.ends_with?(email, "@finngen.fi") and website == "finngen.fi"
  end
end
