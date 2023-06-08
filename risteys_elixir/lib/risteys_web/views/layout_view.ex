defmodule RisteysWeb.LayoutView do
  use RisteysWeb, :view

  # change_release_url is a helper function for creating a link to the same page where the user
  # is but in a selected Risteys version.
  # version_num is the number of the release
  # risteys_version is either "FG" for FinnGen Risteys or "FR_FG" FinRegistry-FinnGen Risteys. Used for setting correct domain in URL
  def change_release_url(conn, version_num, risteys_version) do
    # path to the selected page
    path = conn.request_path

    # Documenatation page used be Methods page in versions before 7.
    # For those versions, direct from Documentation page to Methods page.
    # Check for version, so that function works correctly for future versions and does not change the path.
    # Otherwise, keep the original path
    path =
      if String.contains?(path, "documentation") and version_num < 7 do
        String.replace(path, "documentation", "methods")
      else
        path
      end

    # Endpoint page was /phenocode/<NAME> instead of /endpoints/<NAME> before FINNGEN Risteys version 9
    # However, Risteys FR+FG R8 uses endpoint terminology
    path =
      if version_num < 9 and risteys_version == "FG" do
        String.replace_prefix(path, "/endpoints/", "/phenocode/")
      else
        path
      end

    # URL to current page in a selected version
    # current version numbers need to be manually updated for new versions
    current_FR_FG_version = 11

    # return the URL. Have the rX prefix only for previous Risteys versions
    # different subdomain name for previous FR_FG Risteys versions & sub-subdomain for previous FinnGen Risteys versions
    case {risteys_version, version_num} do
      {"FR_FG", version_num} when version_num == current_FR_FG_version ->
        "https://risteys.finregistry.fi#{path}"

      {"FR_FG", version_num} when version_num < current_FR_FG_version ->
        "https://r#{version_num}.risteys.finregistry.fi#{path}"

      {"FG", version_num} ->
        "https://r#{version_num}.risteys.finngen.fi#{path}"
    end
  end
end
