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
# - step_size
# - nindivs_prior_outcome
# - absolute_risk
# - prior_coef
# - prior_se
# - prior_hr
# - prior_ci_lower
# - prior_ci_upper
# - prior_pval
# - prior_zval
# - prior_norm_mean
# - year_coef
# - year_se
# - year_hr
# - year_ci_lower
# - year_ci_upper
# - year_pval
# - year_zval
# - year_norm_mean
# - sex_coef
# - sex_se
# - sex_hr
# - sex_ci_lower
# - sex_ci_upper
# - sex_pval
# - sex_zval
# - sex_norm_mean
# - bch
# - bch_0
# - bch_2.5
# - bch_5
# - bch_7.5
# - bch_10
# - bch_12.5
# - bch_15
# - bch_17.5
# - bch_20
# - bch_21.99

alias Risteys.{Repo, CoxHR, Phenocode}
import Ecto.Query
require Logger

Logger.configure(level: :info)
[coxhr_filepath | _] = System.argv()

phenos = Repo.all(from p in Phenocode, select: p.name) |> MapSet.new()

coxhr_filepath
|> File.stream!()
|> CSV.decode!(headers: true)
|> Stream.filter(fn %{"prior" => prior, "outcome" => outcome} ->
  prior_in_phenos = MapSet.member?(phenos, prior)

  if not prior_in_phenos do
    Logger.warn("Prior #{prior} not found in phenos")
  end

  outcome_in_phenos = MapSet.member?(phenos, outcome)

  if not outcome_in_phenos do
    Logger.warn("Outcome #{outcome} not found in phenos")
  end

  prior_in_phenos and outcome_in_phenos
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
                   "nindivs_prior_outcome" => n_individuals,
                   "prior_coef" => prior_coef,
                   "prior_norm_mean" => prior_norm_mean,
                   "year_coef" => year_coef,
                   "year_norm_mean" => year_norm_mean,
                   "sex_coef" => sex_coef,
                   "sex_norm_mean" => sex_norm_mean,
                   "bch_0" => bch_year_0,
                   "bch_2.5" => bch_year_2p5,
                   "bch_5" => bch_year_5,
                   "bch_7.5" => bch_year_7p5,
                   "bch_10" => bch_year_10,
                   "bch_12.5" => bch_year_12p5,
                   "bch_15" => bch_year_15,
                   "bch_17.5" => bch_year_17p5,
                   "bch_20" => bch_year_20,
                   "bch_21.99" => bch_year_21p99
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

  sex_coef = if sex_coef == "nan", do: nil, else: String.to_float(sex_coef)
  sex_norm_mean = if sex_norm_mean == "nan", do: nil, else: String.to_float(sex_norm_mean)

  cond do
    hr == "nan" ->
      Logger.warn("NaN HR, not doing import: #{prior} -> #{outcome}")

    ci_max == "inf" ->
      Logger.warn("∞ HR, can't import: #{prior} -> #{outcome}")

    true ->
      # Get the phenocode IDs for prior and outcome
      prior = Repo.get_by!(Phenocode, name: prior)
      outcome = Repo.get_by!(Phenocode, name: outcome)

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
          n_individuals: String.to_integer(n_individuals),
          prior_coef: String.to_float(prior_coef),
          prior_norm_mean: String.to_float(prior_norm_mean),
          year_coef: String.to_float(year_coef),
          year_norm_mean: String.to_float(year_norm_mean),
          sex_coef: sex_coef,
          sex_norm_mean: sex_norm_mean,
          bch_year_0: String.to_float(bch_year_0),
          bch_year_2p5: String.to_float(bch_year_2p5),
          bch_year_5: String.to_float(bch_year_5),
          bch_year_7p5: String.to_float(bch_year_7p5),
          bch_year_10: String.to_float(bch_year_10),
          bch_year_12p5: String.to_float(bch_year_12p5),
          bch_year_15: String.to_float(bch_year_15),
          bch_year_17p5: String.to_float(bch_year_17p5),
          bch_year_20: String.to_float(bch_year_20),
          bch_year_21p99: String.to_float(bch_year_21p99)
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
