require Logger
alias Risteys.{Repo, Phenocode, DrugStats}

Logger.configure(level: :info)
[drug_scores_path | _] = System.argv()


Logger.info("Inserting/Updating drug stats")
drug_scores_path
|> File.stream!()
|> CSV.decode!(headers: true)
|> Stream.reject(fn %{"score" => score, "stderr" => stderr, "endpoint" => endpoint, "atc" => atc} ->
  is_nan = score == "nan" or stderr == "nan"

  if is_nan do
    Logger.warn(
      "Drug score with NaN value for #{endpoint}/#{atc}: score:#{score} ; stderr:#{stderr}"
    )
  end

  is_nan
end)
|> Stream.reject(fn %{"endpoint" => endpoint, "atc" => atc, "n_indivs" => n_indivs} ->
  if n_indivs < 6 do
    Logger.warn("Reject entry for #{endpoint}/#{atc} with indidivual level-data N=#{n_indivs}")
    true
  else
    false
  end
end)
|> Enum.each(fn %{
                  "endpoint" => endpoint,
                  "atc" => atc,
                  "score" => score,
                  "stderr" => stderr,
		  "pvalue" => pvalue,
		  "n_indivs" => n_indivs,
                  "desc" => name,
            } ->
    Logger.debug("Data for #{endpoint} / #{atc}")
    pheno = Repo.get_by(Phenocode, name: endpoint)

  if not is_nil(pheno) do
    drug_stats =
      case Repo.get_by(DrugStats,
             phenocode_id: pheno.id,
             atc: atc
           ) do
        nil -> %DrugStats{}
        existing -> existing
      end

    drug_stats =
      drug_stats
      |> DrugStats.changeset(%{
        phenocode_id: pheno.id,
        atc: atc,
        name: name,
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
