require Logger
alias Risteys.{Repo, Phenocode, ATCDrug, DrugStats}

Logger.configure(level: :info)
[drug_descs_path, drug_scores_path | _] = System.argv()

# ATC drug descriptions
Logger.info("Inserting/Updating drug descriptions")

drug_descs_path
|> File.stream!()
|> CSV.decode!(headers: true)
|> Enum.each(fn %{"code" => atc, "desc" => description} ->
  atc_drug =
    case Repo.get_by(ATCDrug, atc: atc) do
      nil -> %ATCDrug{}
      existing -> existing
    end

  {status, changeset} =
    atc_drug
    |> ATCDrug.changeset(%{atc: atc, description: description})
    |> Repo.insert_or_update()

  case status do
    :ok -> Logger.debug("insert/update ok")
    :error -> Logger.warn(inspect(changeset))
  end
end)

# Drug Stats
Logger.info("Inserting/Updating drug stats")

drug_scores_path
|> File.stream!()
|> CSV.decode!(headers: true)
|> Stream.reject(fn %{"score" => score,
		     "stderr" => stderr,
		     "endpoint" => endpoint,
		     "drug" => atc,
		     "pvalue" => pvalue} ->
  is_nan = score == "nan" or stderr == "nan" or pvalue == "nan"

  if is_nan do
    Logger.warn(
      "Drug score with NaN value for #{endpoint}/#{atc}: score:#{score} ; stderr:#{stderr} ; pvalue:#{pvalue}"
    )
  end

  is_nan
end)
|> Stream.reject(fn %{"endpoint" => endpoint, "drug" => atc, "n_indivs" => n_indivs} ->
  if n_indivs < 6 do
    Logger.warn("Reject entry for #{endpoint}/#{atc} with indidivual level-data N=#{n_indivs}")
    true
  else
    false
  end
end)
|> Enum.each(fn %{
                  "endpoint" => endpoint,
                  "drug" => atc,
                  "score" => score,
                  "stderr" => stderr,
                  "pvalue" => pvalue,
                  "n_indivs" => n_indivs
                } ->
  Logger.debug("Data for #{endpoint} / #{atc}")
  pheno = Repo.get_by(Phenocode, name: endpoint)
  atc_drug = Repo.get_by(ATCDrug, atc: atc)

  if not is_nil(pheno) and not is_nil(atc_drug) do
    drug_stats =
      case Repo.get_by(DrugStats,
             phenocode_id: pheno.id,
             atc_id: atc_drug.id
           ) do
        nil -> %DrugStats{}
        existing -> existing
      end

    drug_stats =
      drug_stats
      |> DrugStats.changeset(%{
        phenocode_id: pheno.id,
        atc_id: atc_drug.id,
        score: score |> String.to_float(),
        stderr: stderr |> String.to_float(),
        pvalue: pvalue |> String.to_float(),
        n_indivs: n_indivs |> String.to_integer()
      })
      |> Repo.insert_or_update()

    case drug_stats do
      {:ok, _} ->
        Logger.debug("insert/update ok")

      {:error, changeset} ->
        Logger.warn(inspect(changeset))
    end
  end
end)

Logger.info("Import done.")
