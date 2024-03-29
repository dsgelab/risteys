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
#       "description": "some text description.",
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
|> Enum.each(fn {name, data} ->
  {description, ontology} = Map.pop(data, "description")

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
