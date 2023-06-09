# Import Cox regression data
#
# Usage:
#   mix run import_coxhr.exs <csv-file-cox>
#
# where <csv-file-cox> is a CSV file with data for many pairs of
# endpoints, with the following header columns:
# - prior
# - outcome
# - lag_hr
# - nindivs_prior_outcome
# - prior_hr
# - prior_ci_lower
# - prior_ci_upper
# - prior_pval

alias Risteys.{FGEndpoint, Repo, CoxHR}
import Ecto.Query
require Logger

Logger.configure(level: :info)
[coxhr_filepath | _] = System.argv()

endpoints = Repo.all(from endpoint in FGEndpoint.Definition, select: endpoint.name) |> MapSet.new()

coxhr_filepath
|> File.stream!()
|> CSV.decode!(headers: true)
|> Stream.filter(fn %{"prior" => prior, "outcome" => outcome} ->
  prior_in_endpoints = MapSet.member?(endpoints, prior)

  if not prior_in_endpoints do
    Logger.warn("Prior #{prior} not found in endpoints")
  end

  outcome_in_endpoints = MapSet.member?(endpoints, outcome)

  if not outcome_in_endpoints do
    Logger.warn("Outcome #{outcome} not found in endpoints")
  end

  prior_in_endpoints and outcome_in_endpoints
end)
|> Stream.with_index()
|> Enum.each(fn {%{
                   "prior" => prior,
                   "outcome" => outcome,
                   "lag_hr" => lagged_years,
                   "prior_hr" => hr,
                   "prior_ci_lower" => ci_min,
                   "prior_ci_upper" => ci_max,
                   "prior_pval" => pvalue,
                   "nindivs_prior_outcome" => n_individuals
                 }, idx} ->
  Logger.debug("Processing pair: #{prior} -> #{outcome}")

  if Integer.mod(idx, 1000) == 0 do
    Logger.info("At line #{idx}")
  end

  lagged_years =
    if lagged_years == "" do
      # can't use nil since lagged_hr is part of a unique constraint
      0
    else
      lagged_years |> String.to_integer() |> trunc
    end

  cond do
    hr == "nan" ->
      Logger.warn("NaN HR, not doing import: #{prior} -> #{outcome}")

    ci_max == "inf" ->
      Logger.warn("∞ HR, can't import: #{prior} -> #{outcome}")

    true ->
      # Get the endpoint IDs for prior and outcome
      prior = Repo.get_by!(FGEndpoint.Definition, name: prior)
      outcome = Repo.get_by!(FGEndpoint.Definition, name: outcome)

      coxhr =
        case Repo.get_by(CoxHR,
               prior_id: prior.id,
               outcome_id: outcome.id,
               lagged_hr_cut_year: lagged_years
             ) do
          nil -> %CoxHR{}
          existing -> existing
        end
        |> CoxHR.changeset(%{
          prior_id: prior.id,
          outcome_id: outcome.id,
          lagged_hr_cut_year: lagged_years,
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
