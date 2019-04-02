alias Risteys.{Repo, ICD10}

Logger.configure(level: :info)

# US ICD-10s
icd10s =
  "assets/data/icd10cm_codes_2019.tsv"
  |> File.stream!()
  |> CSV.decode!(separator: ?\t)
  |> Enum.reduce(%{}, fn [code, description], acc ->
    Map.put(acc, code, description)
  end)

# Finnish ICD-10s
icd10s =
  "assets/data/ICD10_finn_codedesc.tsv"
  |> File.stream!()
  |> CSV.decode!(separator: ?\t, headers: true)
  |> Enum.reduce(icd10s, fn %{"code" => code, "longname" => description}, acc ->
    code = code |> String.replace(".", "")
    Map.put_new(acc, code, description)
  end)

icd10s
|> Enum.map(fn {code, description} ->
  Repo.insert!(%ICD10{code: code, description: description})
end)
