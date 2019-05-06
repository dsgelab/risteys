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
import Ecto.Query

Logger.configure(level: :info)
[filepath | _] = System.argv()


filepath
|> File.read!()
|> Jason.decode!()
|> Enum.each(fn {name, ontology} ->
  Repo.one(from p in Phenocode, where: p.name == ^name)
  |> Ecto.Changeset.change(ontology: ontology)
  |> Repo.update!()
end)
