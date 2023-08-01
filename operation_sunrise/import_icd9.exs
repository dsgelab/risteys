# Import ICD-9 codes into the database
#
# Usage:
# mix run import_icd9.exs <path-to-medcode-ref>
#
# <path-to-medcode-ref>
# - the translation file, provided in FinnGen data by Mary Pat, in CSV format
#   Usually named "finngen_R6_medcode_ref.csv"
#   Must contain the columns:
#   code_set
#   code
#   name_en

alias Risteys.{Repo, Icd9}

Logger.configure(level: :info)
[filepath | _] = System.argv()

filepath
|> File.stream!()
|> CSV.decode!(separator: ?\t, headers: true)
|> Stream.filter(fn %{"code_set" => code_set} -> code_set == "ICD9" end)
|> Stream.map(fn %{"code" => icd9, "name_en" => description} ->
  %Icd9{code: icd9, description: description}
end)
|> Enum.each(&Repo.insert!(&1))
