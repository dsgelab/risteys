# Import ICD10s in the database.
#
# Usage:
# mix run import_icd10.exs <path-to-medcode-ref>
#
# <path-to-medcode-ref>
# - the translation file, provided in FinnGen data by Mary Pat, in CSV format
#   Usually named "finngen_R6_medcode_ref.csv"
#   Must contain the columns:
#   code_set
#   code
#   name_en

require Logger
alias Risteys.{Repo, Icd10} # makes aliases of the Risteys.Repo and Risteys.Icd10 modules. Icd10 contains schema and changeset

Logger.configure(level: :info) # configures the logger
# save path to data. System.argv() lists command line arguments.
# By taking the head of the list, just the first element, i.e. the path is taken, not a list
[code_translations | _] = System.argv()

# Finnish ICD-10s
Logger.info("Loading ICD-10s")

# save data to "icd10s" variable: a map of each ICD-10 code
icd10s =
  code_translations # path to data
  # reads in the data one line at the time and passes it to the next part in the pipeline.
  # the data can be used as an enumerable
  |> File.stream!()
  # header: true -> first row as header values. headers part is needed in order to make a map.
  # Decodes a stream of comma-separated lines into a stream of tuples.
  |> CSV.decode!(headers: true)
  # Using "code_set" column, filters the data to include only ICD10 codes
  |> Stream.filter(fn %{"code_set" => code_set} -> code_set == "ICD10" end)
  # makes a map for each row, where value in "code" column is the key, and value in "name_en" column is the value.
  |> Enum.reduce(%{}, fn %{"code" => code, "name_en" => description}, acc ->
    Map.put(acc, code, description)
  end)

Logger.info("Inserting ICD-10s in the database.")

# import data to the database
icd10s
|> Enum.map(fn {code, description} ->
  case Repo.get_by(Icd10, code: code) do
    nil -> %Icd10{}
    existing -> existing
  end
  |> Icd10.changeset(%{code: code, description: description})
  |> Repo.insert_or_update!()
end)
