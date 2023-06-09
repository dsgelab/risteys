# Import information about excluded endpoints into the fg_endpoint_definitions table in the database

# Usage: mix run import_excluded_endpoints.exs path_to_excluded_endpoints.csv

# excluded_endpoints.csv file has columns "FR_EXCL" and "NAME"
# NAME: endpoint name. data type: string.
# FR_EXCL: reason why endpoint is excluded. data type: string.

alias Risteys.Repo
alias Risteys.FGEndpoint.Definition
require Logger

Logger.configure(level: :info)
[filepath | _] = System.argv()

Logger.info("Loading data")

excl_endpoints =
  filepath
  |> File.stream!()
  |> CSV.decode!(headers: :true)
  |> Enum.reduce(%{}, fn %{"FR_EXCL" => fr_excl, "NAME" => name}, acc ->
    Map.put(acc, name, fr_excl)
  end)

Logger.info("Start importing data into the DB.")
# import data to the database
excl_endpoints
  |> Enum.each(fn {name, fr_excl} ->

    Logger.info("Importing #{name}…")

    # Update the endpoint definition with the exclusion reason data
    case Repo.get_by(Definition, name: name) do
      nil ->
        Logger.debug(
          "Endpoint #{name} not in DB. skipping."
        )

      endpoint ->
        changeset = Definition.changeset(endpoint, %{fr_excl: fr_excl})
        Repo.try_update(%Definition{}, changeset)
    end
  end)

Logger.info("End of import script.")
