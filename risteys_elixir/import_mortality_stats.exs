alias Risteys.{Repo, MortalityStats, Phenocode}
import Ecto.Query
require Logger

Logger.configure(level: :info)
[stats_filepath | _] = System.argv()

phenos = Repo.all(from p in Phenocode, select: p.name) |> MapSet.new()

stats_filepath
|> File.stream!()
|> CSV.decode!(headers: true)
|> Stream.filter(fn %{"endpoint" => pheno} ->
  # returns true, if phenos mapset contains pheno value, i.e. the endpoint that was read in. if not found, returns false.
  in_pheno = MapSet.member?(phenos, pheno)

  if not in_pheno do # when not found, i.e, when in_pheno is false. not false returns true
    Logger.warn("Phenocode #{pheno} not found in DB, skipping.")
  end

  in_pheno # when in_pheno is true
end)
|> Enum.each(fn %{
                  "endpoint" => pheno,
                  "lag_hr" => lag_hr,
                  "endpoint_hr" => hr,
                  "endpoint_ci_lower" => hr_ci_min,
                  "endpoint_ci_upper" => hr_ci_max,
                  "endpoint_pval" => pvalue,
                  "nindivs_prior_later" => nindivs,
                  "absolute_risk" => abs_risk
                } ->
  lag_hr =
    if lag_hr == "" do
      0
    else
      lag_hr |> String.to_integer()
    end

  pheno = Repo.get_by!(Phenocode, name: pheno)

  stat =
    case Repo.get_by(MortalityStats, phenocode_id: pheno.id, lagged_hr_cut_year: lag_hr) do
      nil -> %MortalityStats{}
      existing -> existing
    end
    |> MortalityStats.changeset(%{
      phenocode_id: pheno.id,
      lagged_hr_cut_year: lag_hr,
      hr: String.to_float(hr),
      hr_ci_min: String.to_float(hr_ci_min),
      hr_ci_max: String.to_float(hr_ci_max),
      pvalue: String.to_float(pvalue),
      n_individuals: String.to_integer(nindivs),
      absolute_risk: String.to_float(abs_risk)
    })
    |> Repo.insert_or_update()

  case stat do
    {:ok, _} ->
      Logger.debug("insert/update ok")

    {:error, changeset} ->
      Logger.warn(inspect(changeset))
  end
end)
