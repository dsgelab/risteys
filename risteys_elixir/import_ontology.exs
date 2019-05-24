# Import ontology data into the database
#
# Usage:
#     mix run import_ontology.exs <json-file-ontology>
#
# where <json-file-ontology> is a JSON file containing ontology data
# with the following structure:
# {
#   "<endpoint-name>": {
#     {
#       "<ontology-name>": [val1, val2, ...],
#       ...
#     }
#   },
#   ...
# }
#
# The map data for each endpoint will be imported "as is" in a row
# cell in the database.

alias Risteys.{Repo, Phenocode}
require Logger

Logger.configure(level: :info)
[filepath | _] = System.argv()

filepath
|> File.read!()
|> Jason.decode!()
|> Enum.each(fn {name, ontology} ->
  # Merge SNOMEDCT and SNOMED_CT values
  snomedct =
    ontology
    |> Map.get("SNOMEDCT_US_2018_03_01", [])
    |> MapSet.new()

  snomed_ct =
    ontology
    |> Map.get("SNOMED_CT_US_2018_03_01", [])
    |> MapSet.new()

  snomed =
    MapSet.union(snomedct, snomed_ct)
    |> Enum.to_list()

  # Get the description from the ontology.
  # This will be added at the phenocode level so it can be queried.
  description =
    Map.get(ontology, "DESCRIPTION", [])
    |> Enum.reject(fn d -> d == "No definition available" end)
    |> Enum.join(" ")

  description = if description == "", do: nil, else: description

  # Remove ontology types we don't need
  keep_keys =
    ontology
    |> Map.keys()
    |> MapSet.new()
    |> MapSet.intersection(Phenocode.allowed_ontology_types())

  current_keys =
    ontology
    |> Map.keys()
    |> MapSet.new()

  remove_keys = MapSet.difference(current_keys, keep_keys)
  ontology = Map.drop(ontology, remove_keys)

  # Add SNOMED into the ontology
  ontology =
    if "SNOMEDCT_US_2018_03_01" in current_keys or "SNOMED_CT_US_2018_03_01" in current_keys do
      Logger.debug("got SNOMED data")
      Map.put(ontology, "SNOMED", snomed)
    end

  # Update the phenocode with the ontology and description
  case Repo.get_by(Phenocode, name: name) do
    nil ->
      Logger.debug(
        "Phenocode #{name} not in DB, may be not imported due to restrictions on OMIT or LEVEL."
      )

    phenocode ->
      changeset = Phenocode.changeset(phenocode, %{ontology: ontology, description: description})
      Repo.try_update(%Phenocode{}, changeset)
  end
end)
