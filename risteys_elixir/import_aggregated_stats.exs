# Import pre-processed / aggregated data in the database
#
# Usage:
#     mix run import_aggregated_data.exs <json-file-aggregegated-stats>
#
# where <json-file-aggregegated-stats> is a JSON file with all the
# aggregated stats, with the following format:
#
# {
#   "stats":
#   "ENDPOINT XYZ": {
#     ...
#   },
#   ...
#   "distrib_age":
#   "ENDPOINT XYZ": {
#     ...
#   },
#   ...
#   "distrib_year":
#   "ENDPOINT XYZ": {
#     ...
#   },
#   ...
# }

alias Risteys.{Repo, Phenocode, StatsSex}
require Logger

Logger.configure(level: :info)
[stats_filepath | _] = System.argv()

defmodule Risteys.ImportAgg do
  def stats(
        phenocode,
        sex,
        case_fatality,
        mean_age,
        median_reoccurence,
        n_individuals,
        prevalence,
        reoccurence_rate,
        distrib_year,
        distrib_age
      ) do
    # Wrap distributions in a map
    distrib_year = %{hist: distrib_year}
    distrib_age = %{hist: distrib_age}

    stats =
      case Repo.get_by(StatsSex, sex: sex, phenocode_id: phenocode.id) do
        nil -> %StatsSex{}
        existing -> existing
      end
      |> StatsSex.changeset(%{
        phenocode_id: phenocode.id,
        sex: sex,
        case_fatality: case_fatality,
        mean_age: mean_age,
        median_reoccurence: median_reoccurence,
        n_individuals: n_individuals,
        prevalence: prevalence,
        reoccurence_rate: reoccurence_rate,
        distrib_year: distrib_year,
        distrib_age: distrib_age
      })
      |> Repo.insert_or_update()

    case stats do
      {:ok, _} ->
        Logger.debug("insert ok for #{phenocode.name} - sex: #{sex}")

      {:error, changeset} ->
        Logger.warn(inspect(changeset))
    end
  end
end

# Parse the data
%{
  "stats" => stats,
  "distrib_year" => distrib_year,
  "distrib_age" => distrib_age
} =
  stats_filepath
  |> File.read!()
  |> Jason.decode!()

# Add stats to DB
stats
|> Enum.each(fn {name, data} ->
  Logger.info("Processing stats for #{name}")

  phenocode = Repo.get_by(Phenocode, name: name)

  cond do
    is_nil(phenocode) ->
      Logger.warn("Skipping stats for #{name}: not in DB")

    true ->
      # Import stats for this phenocode
      %{
        "nindivs_all" => nindivs_all,
        "nindivs_female" => nindivs_female,
        "nindivs_male" => nindivs_male,
        "case_fatality_all" => case_fatality_all,
        "case_fatality_female" => case_fatality_female,
        "case_fatality_male" => case_fatality_male,
        "mean_age_all" => mean_age_all,
        "mean_age_female" => mean_age_female,
        "mean_age_male" => mean_age_male,
        "median_events_all" => median_events_all,
        "median_events_female" => median_events_female,
        "median_events_male" => median_events_male,
        "prevalence_all" => prevalence_all,
        "prevalence_female" => prevalence_female,
        "prevalence_male" => prevalence_male,
        "reoccurence_all" => reoccurence_all,
        "reoccurence_female" => reoccurence_female,
        "reoccurence_male" => reoccurence_male
      } = data

      %{
        "all" => distrib_year_all,
        "female" => distrib_year_female,
        "male" => distrib_year_male
      } = Map.fetch!(distrib_year, name)

      %{
        "all" => distrib_age_all,
        "female" => distrib_age_female,
        "male" => distrib_age_male
      } = Map.fetch!(distrib_age, name)

      # Cast to correct number types
      nindivs_all = if is_nil(nindivs_all), do: nil, else: floor(nindivs_all)
      nindivs_female = if is_nil(nindivs_female), do: nil, else: floor(nindivs_female)
      nindivs_male = if is_nil(nindivs_male), do: nil, else: floor(nindivs_male)
      median_events_all = if is_nil(median_events_all), do: nil, else: floor(median_events_all)

      median_events_female =
        if is_nil(median_events_female) do
          nil
        else
          floor(median_events_female)
        end

      median_events_male =
        if is_nil(median_events_male) do
          nil
        else
          floor(median_events_male)
        end

      # sex: all
      # Don't import anything if Nindivs = 0 (really no events with this phenotype) or
      # Nindivs = nil (individual-level data).
      if not is_nil(nindivs_all) and floor(nindivs_all) != 0 do
        Risteys.ImportAgg.stats(
          phenocode,
          0,
          case_fatality_all,
          mean_age_all,
          median_events_all,
          nindivs_all,
          prevalence_all,
          reoccurence_all,
          distrib_year_all,
          distrib_age_all
        )
      else
        Logger.warn("Skipping stats for #{phenocode.name} - all : None or 0 individual")
      end

      # sex: male
      if not is_nil(nindivs_male) and floor(nindivs_male) != 0 do
        Risteys.ImportAgg.stats(
          phenocode,
          1,
          case_fatality_male,
          mean_age_male,
          median_events_male,
          nindivs_male,
          prevalence_male,
          reoccurence_male,
          distrib_year_male,
          distrib_age_male
        )
      else
        Logger.warn("Skipping stats for #{phenocode.name} - male : None or 0 individual")
      end

      # sex: female
      if not is_nil(nindivs_female) and floor(nindivs_female) != 0 do
        Risteys.ImportAgg.stats(
          phenocode,
          2,
          case_fatality_female,
          mean_age_female,
          median_events_female,
          nindivs_female,
          prevalence_female,
          reoccurence_female,
          distrib_year_female,
          distrib_age_female
        )
      else
        Logger.warn("Skipping stats for #{phenocode.name} - female : None or 0 individual")
      end
  end
end)
