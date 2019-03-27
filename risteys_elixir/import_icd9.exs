alias Risteys.{Repo, ICD9}

Logger.configure(level: :info)

"assets/data/icd9_SimoP.txt"
|> File.stream!()
### |> Stream.take(3)
|> CSV.decode!(separator: ?\t, headers: true)
|> Stream.map(fn %{"ICD9" => icd9, "ICD9TXT" => description} ->
  %ICD9{code: icd9, description: description}
end)
|> Enum.each(&Repo.insert!(&1))
