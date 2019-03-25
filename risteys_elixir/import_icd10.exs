alias Risteys.{Repo, ICD10}

Logger.configure(level: :info)

"assets/data/icd10cm_codes_2019.tsv"
|> File.stream!()
|> CSV.decode!(separator: ?\t)
|> Stream.map(fn [code, description] ->
  %ICD10{code: code, description: description}
end)
|> Enum.each(&Repo.insert!(&1))
