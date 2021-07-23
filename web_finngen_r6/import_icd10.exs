# Import ICD10s in the database.
#
# Usage:
# mix run import_icd10.exs <path-to-medcode-ref>
#
# <path-to-medcode-ref>
# - the translation file, provided in FinnGen data by Mary Pat, in CSV format
#   Usually named "finngen_R6_medcode_ref.csv"
#   Must contain the columns:
#   . code
#   . name_en

require Logger
alias Risteys.{Repo, Icd10}

Logger.configure(level: :info)
[code_translations | _] = System.argv()

# Finnish ICD-10s
Logger.info("Loading ICD-10s")

icd10s =
  code_translations
  |> File.stream!()
  |> CSV.decode!(headers: true)
  |> Stream.filter(fn %{"code_set" => code_set} -> code_set == "ICD10" end)
  |> Enum.reduce(%{}, fn %{"code" => code, "name_en" => description}, acc ->
    Map.put(acc, code, description)
  end)

Logger.info("Inserting ICD-10s in the database.")

icd10s
|> Enum.map(fn {code, description} ->
  case Repo.get_by(Icd10, code: code) do
    nil -> %Icd10{}
    existing -> existing
  end
  |> Icd10.changeset(%{code: code, description: description})
  |> Repo.insert_or_update!()
end)
