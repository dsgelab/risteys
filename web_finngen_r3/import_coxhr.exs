# Import Cox regression data
#
# Usage:
#   mix run import_coxhr.exs <csv-file-cox>
#
# where <csv-file-cox> is a CSV file with data for many pairs of
# endpoints, with the following header:
# prior,later,hr,ci_lower,ci_upper,p-value,concordance,nindivs_prior_later


alias Risteys.{Repo, CoxHR, Phenocode}
require Logger

Logger.configure(level: :info)
[coxhr_filepath | _] = System.argv()

coxhr_filepath
|> File.stream!()
|> CSV.decode!(headers: true)
|> Enum.each(fn %{
                  "prior" => prior,
                  "later" => outcome,
                  "hr" => hr,
                  "ci_lower" => ci_min,
                  "ci_upper" => ci_max,
                  "p-value" => pvalue,
                  "nindivs_prior_later" => n_individuals
                } ->
  Logger.debug("Processing pair: #{prior} -> #{outcome}")

  case hr do
    "nan" ->
      Logger.warn("NaN HR, not doing import")

    _ ->
      # Get the phenocode IDs for prior and outcome
      prior = Repo.get_by!(Phenocode, name: prior)
      outcome = Repo.get_by!(Phenocode, name: outcome)

      coxhr =
        case Repo.get_by(CoxHR, prior_id: prior.id, outcome_id: outcome.id) do
          nil -> %CoxHR{}
          existing -> existing
        end
        |> CoxHR.changeset(%{
          prior_id: prior.id,
          outcome_id: outcome.id,
          hr: String.to_float(hr),
          ci_min: String.to_float(ci_min),
          ci_max: String.to_float(ci_max),
          pvalue: String.to_float(pvalue),
          n_individuals: String.to_integer(n_individuals)
        })
        |> Repo.insert_or_update()

      case coxhr do
        {:ok, _} ->
          Logger.debug("insert/update ok")

        {:error, changeset} ->
          Logger.warn(inspect(changeset))
      end
  end
end)
