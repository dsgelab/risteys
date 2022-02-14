# Import pre-processed / aggregated data in the database.
# Clean-up endpoints without statistics afterwards.
#
# Usage:
#     mix run import_aggregated_stats.exs <json-file-aggregegated-stats> <dataset>
#
# where
# <json-file-aggregegated-stats> is a JSON file with all the
# aggregated stats, with the following format:
#
# {
#   "stats":
#   {"ENDPOINT XYZ": {
#     ...
#   },
#   ...},
#   "distrib_age":
#   {"ENDPOINT XYZ": {
#     ...
#   },
#   ...},
#   "distrib_year":
#   {"ENDPOINT XYZ": {
#     ...
#   },
#   ...}
# }
#
# and dataset is a string indicating which project the reults belong to,
# either "FG" for FinnGen or "FR" for FinRegistry

alias Risteys.{Repo, Phenocode, StatsSex}
require Logger

Logger.configure(level: :info)
[stats_filepath, dataset | _] = System.argv()

# raise an error if correct dataset info is not provided
if dataset != "FG" and dataset != "FR" do
  raise ArgumentError, message: "Dataset need to be given as a second argument, either FG or FR."
end

defmodule Risteys.ImportAgg do
  def stats(
        phenocode,
        sex,
        mean_age,
        n_individuals,
        prevalence,
        distrib_year,
        distrib_age,
        dataset
      ) do
    # Wrap distributions in a map
    distrib_year = %{hist: distrib_year}
    distrib_age = %{hist: distrib_age}

    stats =
      # update existing table if data with same phenocode id, sex and prjoect is already in the db
      case Repo.get_by(StatsSex, sex: sex, phenocode_id: phenocode.id, dataset: dataset) do
        nil -> %StatsSex{}
        existing -> existing
      end
      |> StatsSex.changeset(%{
        phenocode_id: phenocode.id,
        sex: sex,
        mean_age: mean_age,
        n_individuals: n_individuals,
        prevalence: prevalence,
        distrib_year: distrib_year,
        distrib_age: distrib_age,
        dataset: dataset
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
  # Returns a binary with the contents of the given filename, or raises a File.Error exception if an error occurs.
  # "{\"stats\": {\"AB1TUBERCU_MILIARY\":{\"nindivs_all\":33.0,\"nindivs_female\":8.0,\"nindivs_male\":25.0,\"prevalence_all\":0.000102942,\"prevalence_female\":0.0000443698,\"prevalence_male\":0.0001782328,\"mean_age_all\":63.1203030303,\"mean_age_female\":51.95625,\"mean_age_male\":66.6928},\"AB1_ACTINOMYCOSIS\":{\"nindivs_all\":77.0, ...
  |> File.read!() # asking OS to open the file to access the file reading content
  |> Jason.decode!() # Parses a JSON value from input iodata. read the file as JSON and convert values to values that can be used in Elixir

# Add stats to DB
stats # stats from the map???
|> Enum.each(fn {name, data} -> # goes through each endpoint and its stats
  Logger.info("Processing stats for #{name}")

  phenocode = Repo.get_by(Phenocode, name: name) # gets the endpoint name from the phenocodes table in the db

  case phenocode do
    nil -> # phenocode not found from the db
      Logger.warn("Skipping stats for #{name}: not in DB")

    _ -> # when phenocode is not nil
      # Import stats for this phenocode
      # the data for each enpoint in stats has below data -> pattern matching? is used to create a map
      %{
        "nindivs_all" => nindivs_all,
        "nindivs_female" => nindivs_female,
        "nindivs_male" => nindivs_male,
        "mean_age_all" => mean_age_all,
        "mean_age_female" => mean_age_female,
        "mean_age_male" => mean_age_male,
        "prevalence_all" => prevalence_all,
        "prevalence_female" => prevalence_female,
        "prevalence_male" => prevalence_male
      } = data

      # Distribution are missing for endpoints with total N in 1..4
      empty_distrib = %{"all" => [], "female" => [], "male" => []}

      # for each endpoint, create a map of year distributions for females, males, and all
      # by using pattern matching? to match the data from distrib_year map
      # get(map, key, default \\ nil). -> if endpoint ("name" key) is present in the map (distrib_year),
      # get the data from the map, otherwise return empty_distrib, i.e. []
      %{
        "all" => distrib_year_all,
        "female" => distrib_year_female,
        "male" => distrib_year_male
      } = Map.get(distrib_year, name, empty_distrib)

      %{
        "all" => distrib_age_all,
        "female" => distrib_age_female,
        "male" => distrib_age_male
      } = Map.get(distrib_age, name, empty_distrib)

      # Cast to correct number types
      nindivs_all = if is_nil(nindivs_all), do: nil, else: floor(nindivs_all)
      nindivs_female = if is_nil(nindivs_female), do: nil, else: floor(nindivs_female)
      nindivs_male = if is_nil(nindivs_male), do: nil, else: floor(nindivs_male)

      # Import aggregated stats to the db using the stats function
      # sex: all
      # Don't import anything if Nindivs = 0 (really no events with this phenotype) or
      # Nindivs = nil (individual-level data).
      if not is_nil(nindivs_all) and floor(nindivs_all) != 0 do
        Risteys.ImportAgg.stats(
          phenocode,
          0,
          mean_age_all,
          nindivs_all,
          prevalence_all,
          distrib_year_all,
          distrib_age_all,
          dataset
        )
      else
        Logger.warn("Skipping stats for #{phenocode.name} - all : None or 0 individual")
      end

      # sex: male
      if not is_nil(nindivs_male) and floor(nindivs_male) != 0 do
        Risteys.ImportAgg.stats(
          phenocode,
          1,
          mean_age_male,
          nindivs_male,
          prevalence_male,
          distrib_year_male,
          distrib_age_male,
          dataset
        )
      else
        Logger.warn("Skipping stats for #{phenocode.name} - male : None or 0 individual")
      end

      # sex: female
      if not is_nil(nindivs_female) and floor(nindivs_female) != 0 do
        Risteys.ImportAgg.stats(
          phenocode,
          2,
          mean_age_female,
          nindivs_female,
          prevalence_female,
          distrib_year_female,
          distrib_age_female,
          dataset
        )
      else
        Logger.warn("Skipping stats for #{phenocode.name} - female : None or 0 individual")
      end
  end
end)
