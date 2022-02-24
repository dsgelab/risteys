# Import information about excluded endpoints into the phenocodes table in the database

# Usage: mix run import_excluded_endpoints.exs path_to_excluded_endpoints.csv

# excluded_endpoints.csv file has columns "FR_EXCL" and "NAME"
# NAME: endpoint name. data type: string.
# FR_EXCL: reason why endpoint is excluded. data type: string.

alias Risteys.{Repo, Phenocode}
import Ecto.Query
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

    # Update the phenocode with the exclusion reason data
    case Repo.get_by(Phenocode, name: name) do
      nil ->
        Logger.debug(
          "Phenocode #{name} not in DB. skipping."
        )

      phenocode ->
        changeset = Phenocode.changeset(phenocode, %{fr_excl: fr_excl})
        Repo.try_update(%Phenocode{}, changeset)
    end
  end)

Logger.info("End of import script.")
