defmodule RisteysWeb.LayoutView do
  use RisteysWeb, :view

  alias RisteysWeb.ViewHelpers

  # change_release_url is a helper function for creating a link to the same page where the user
  # is but in a selected Risteys version.
  def change_release_url(conn, version) do
    # path to the selected page
    path = conn.request_path

    # Documenatation page used be Methods page in versions before 7.
    # For those versions, direct from Documentation page to Methods page.
    # Check for version, so that function works correctly for future versions and does not change the path.
    # Otherwise, keep the original path
    path =
      if String.contains?(path, "documentation") and version < 7 do
        String.replace(path, "documentation", "methods")
      else
        path
      end

    # Endpoint page was /phenocode/<NAME> instead of /endpoints/<NAME> before version 9
    path =
      if version < 9 do
        String.replace_prefix(path, "/endpoints/", "/phenocode/")
      else
        path
      end

    # URL to current page in a selected version
    "https://r#{version}.risteys.finngen.fi#{path}"
  end
end
