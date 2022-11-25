# Import key figures data in the database.
# Clean-up endpoints without statistics afterwards.
#
# Usage:
#     mix run import_key_figures.exs <csv-file-key-figures>
#
# where <csv-file-key-figures> is a CSV file with all the key figures,
# with the following headers:
# - endpoint
# - nindivs_all
# - nindivs_female
# - nindivs_male
# - median_age_all
# - median_age_female
# - median_age_male
# - prevalence_all
# - prevalence_female
# - prevalence_male



alias Risteys.{FGEndpoint, Repo, StatsSex}
require Logger

Logger.configure(level: :info)
[key_figures_filepath | _] = System.argv()

defmodule Risteys.ImportAgg do
  def stats(
        endpoint,
        sex,
        mean_age,
        n_individuals,
        prevalence,
        distrib_year,
        distrib_age
      ) do
    # Wrap distributions in a map
    distrib_year = %{hist: distrib_year}
    distrib_age = %{hist: distrib_age}

    stats =
      case Repo.get_by(StatsSex, sex: sex, fg_endpoint_id: endpoint.id) do
        nil -> %StatsSex{}
        existing -> existing
      end
      |> StatsSex.changeset(%{
        fg_endpoint_id: endpoint.id,
        sex: sex,
        mean_age: mean_age,
        n_individuals: n_individuals,
        prevalence: prevalence,
        distrib_year: distrib_year,
        distrib_age: distrib_age
      })
      |> Repo.insert_or_update()

    case stats do
      {:ok, _} ->
        Logger.debug("insert ok for #{endpoint.name} - sex: #{sex}")

      {:error, changeset} ->
        Logger.warn(inspect(changeset))
    end
  end
end

# Parse the data
key_figures_path
|> File.stream!()
|> CSV.decode!(headers: true)

|> Stream.map(fn row ->
  %{
    "endpoint"          => name,
    "nindivs_all"       => nindivs_all,
    "nindivs_female"    => nindivs_female,
    "nindivs_male"      => nindivs_male,
    "median_age_all"    => median_age_all,
    "median_age_female" => median_age_female,
    "median_age_male"   => median_age_male,
    "prevalence_all"    => prevalence_all,
    "prevalence_female" => prevalence_female,
    "prevalence_male"   => prevalence_male,
  } = row

  %{
    endpoint:           name,
    nindivs_all:        nindivs_all,
    nindivs_female:     nindivs_female,
    nindivs_male:       nindivs_male,
    median_age_all:     median_age_all,
    median_age_female:  median_age_female,
    median_age_male:    median_age_male,
    prevalence_all:     prevalence_all,
    prevalence_female:  prevalence_female,
    prevalence_male:    prevalence_male,
  }
end)
# Convert "" to nil
|> Stream.map(fn row ->
  Enum.map(row, fn {name, value} ->
    if value == "" do
      nil
    else
      value
    end
  end)
end)

# Discard rows based on number of individuals
|> Stream.reject(fn row ->
  reject_endpoint = (
    is_nil(row.nindivs_all) or is_nil(row.nindivs_female) or is_nil(row.nindivs_male)
    or row.nindivs_all == 0 or row.nindivs_female == 0 or row.nindivs_male == 0
  )
  
  if reject_endpoint do
    Logger.warning("Rejecting #{row.endpoint} based on number of individuals")
  end
  
  reject_endpoint
end)

|> Enum.each(fn row ->
  
  Logger.info("Processing stats for #{name}")
  
  # Convert to right value type
  nindivs_all    = String.to_float(nindivs_all) |> floor()
  nindivs_female = String.to_float(nindivs_female) |> floor()
  nindivs_male   = String.to_float(nindivs_male) |> floor()
  median_age_all = String.to_float(median_age_all)
  median_age_female = String.to_float(median_age_female)
  median_age_male = String.to_float(median_age_male)
  prevalence_all = String.to_float(prevalence_all)
  prevalence_female = String.to_float(prevalence_female)
  prevalence_male = String.to_float(prevalence_male)
  
  case Repo.get_by(FGEndpoint.Definition, name: name) do
    nil ->
      Logger.warn("Skipping #{name}: not found in DB")
      
    endpoint ->
    
  end
  
end)




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

  endpoint = Repo.get_by(FGEndpoint.Definition, name: name)

  case endpoint do
    nil ->
      Logger.warn("Skipping stats for #{name}: not in DB")

    _ ->
      # Import stats for this endpoint
      %{
        "nindivs_all" => nindivs_all,
        "nindivs_female" => nindivs_female,
        "nindivs_male" => nindivs_male,
        "mean_age_all" => mean_age_all,
        "mean_age_female" => mean_age_female,
        "mean_age_male" => mean_age_male,
        "prevalence_all" => prevalence_all,
        "prevalence_female" => prevalence_female,
        "prevalence_male" => prevalence_male,
      } = data

      # Distribution are missing for endpoints with total N in 1..4
      empty_distrib = %{"all" => [], "female" => [], "male" => []}
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

      # sex: all
      # Don't import anything if Nindivs = 0 (really no events with this endpoint) or
      # Nindivs = nil (individual-level data).
      if not is_nil(nindivs_all) and floor(nindivs_all) != 0 do
        Risteys.ImportAgg.stats(
          endpoint,
          0,
          mean_age_all,
          nindivs_all,
          prevalence_all,
          distrib_year_all,
          distrib_age_all
        )
      else
        Logger.warn("Skipping stats for #{endpoint.name} - all : None or 0 individual")
      end

      # sex: male
      if not is_nil(nindivs_male) and floor(nindivs_male) != 0 do
        Risteys.ImportAgg.stats(
          endpoint,
          1,
          mean_age_male,
          nindivs_male,
          prevalence_male,
          distrib_year_male,
          distrib_age_male
        )
      else
        Logger.warn("Skipping stats for #{endpoint.name} - male : None or 0 individual")
      end

      # sex: female
      if not is_nil(nindivs_female) and floor(nindivs_female) != 0 do
        Risteys.ImportAgg.stats(
          endpoint,
          2,
          mean_age_female,
          nindivs_female,
          prevalence_female,
          distrib_year_female,
          distrib_age_female
        )
      else
        Logger.warn("Skipping stats for #{endpoint.name} - female : None or 0 individual")
      end
  end
end)
