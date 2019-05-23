# Import pre-processed / aggregated data in the database
#
# Usage:
#     mix run import_aggregated_data.exs <json-file-aggregegated-stats>
#
# where <json-file-aggregegated-stats> is a JSON file with all the
# aggregated stats, with the following format:
#
# {
#   "ENDPOINT XYZ": {
#     "year_distrib": [...],
#     "age_distrib": [...],
#     "longit": {...},
#     "common_stats": {...},
#   },
#   ...
# }

alias Risteys.{Repo, Phenocode, StatsSex}
require Logger

Logger.configure(level: :info)
[filepath | _] = System.argv()

# Get the number of individuals for all/female/male
{total_indivs, total_females, total_males} =
  filepath
  |> File.read!()
  |> Jason.decode!()
  |> Enum.reduce({0, 0, 0}, fn {_name, data}, {cnt_indivs, cnt_females, cnt_males} ->
    case Map.get(data, "common_stats") do
      nil ->
        {cnt_indivs, cnt_females, cnt_males}

      common_stats ->
        %{
          "all" => %{"nindivs" => nall},
          "female" => %{"nindivs" => nfemales},
          "male" => %{"nindivs" => nmales}
        } = common_stats

        {
          cnt_indivs + nall,
          cnt_females + nfemales,
          cnt_males + nmales
        }
    end
  end)

filepath
|> File.read!()
|> Jason.decode!()
|> Enum.each(fn {name, data} ->
  Logger.info("processing #{name}")

  phenocode = Repo.get_by(Phenocode, name: name)

  cond do
    is_nil(Map.get(data, "common_stats")) ->
      Logger.warn("Skipping #{name}: no common_stats")

    is_nil(phenocode) ->
      Logger.warn("Skipping. #{name} not in DB")

    true ->
      # Update phenocode with stats distributions
      year_distrib = Map.get(data, "year_distrib")
      # wrap the list of lists into a map
      year_distrib = %{hist: year_distrib}
      Logger.debug("year_distrib: #{inspect(year_distrib)}")

      changeset = Phenocode.changeset(phenocode, %{distrib_year: year_distrib})
      Logger.debug("Applying Phenocode changeset: #{inspect(changeset)}")
      phenocode = Repo.try_update(phenocode, changeset)

      age_distrib = Map.get(data, "age_distrib")
      # wrap the list of lists into a map
      age_distrib = %{hist: age_distrib}
      Logger.debug("age_distrib: #{inspect(age_distrib)}")

      changeset = Phenocode.changeset(phenocode, %{distrib_age: age_distrib})
      Logger.debug("Applying Phenocode changeset: #{inspect(changeset)}")
      phenocode = Repo.try_update(phenocode, changeset)

      # Create stats table for sex=all
      all_case_fatality =
        data |> Map.get("common_stats", %{}) |> Map.get("all", %{}) |> Map.get("case_fatality")

      all_nindivs =
        data |> Map.get("common_stats", %{}) |> Map.get("all", %{}) |> Map.get("nindivs")

      all_mean_age =
        data |> Map.get("common_stats", %{}) |> Map.get("all", %{}) |> Map.get("mean_age")

      all_median_reoccurence =
        data |> Map.get("longit", %{}) |> Map.get("all", %{}) |> Map.get("median_count")

      Logger.debug("median reoccurence before trunc: #{all_median_reoccurence}")

      all_median_reoccurence =
        if not is_nil(all_median_reoccurence) do
          trunc(all_median_reoccurence)
        end

      Logger.debug("median reoccurence after trunc: #{all_median_reoccurence}")

      all_reoccurence_rate =
        data |> Map.get("longit", %{}) |> Map.get("all", %{}) |> Map.get("perc_hosp")

      result_all_stats =
        case Repo.get_by(StatsSex, sex: 0, phenocode_id: phenocode.id) do
          nil -> %StatsSex{}
          stats -> stats
        end
        |> StatsSex.changeset(%{
          phenocode_id: phenocode.id,
          sex: 0,
          case_fatality: all_case_fatality,
          mean_age: all_mean_age,
          median_reoccurence: all_median_reoccurence,
          n_individuals: all_nindivs,
          prevalence: all_nindivs / total_indivs,
          reoccurence_rate: all_reoccurence_rate
        })
        |> Repo.insert_or_update()

      case result_all_stats do
        {:ok, _} ->
          Logger.debug("insert ok for #{name} - all")

        {:error, changeset} ->
          Logger.warn(inspect(changeset))
      end

      # Create stats table for sex=female
      female_case_fatality =
        data |> Map.get("common_stats", %{}) |> Map.get("female", %{}) |> Map.get("case_fatality")

      female_nindivs =
        data |> Map.get("common_stats", %{}) |> Map.get("female", %{}) |> Map.get("nindivs")

      female_mean_age =
        data |> Map.get("common_stats", %{}) |> Map.get("female", %{}) |> Map.get("mean_age")

      female_median_reoccurence =
        data
        |> Map.get("longit", %{})
        |> Map.get("female", %{})
        |> Map.get("median_count")

      female_median_reoccurence =
        if not is_nil(female_median_reoccurence) do
          trunc(female_median_reoccurence)
        end

      female_reoccurence_rate =
        data |> Map.get("longit", %{}) |> Map.get("female", %{}) |> Map.get("perc_hosp")

      result_female_stats =
        case Repo.get_by(StatsSex, sex: 2, phenocode_id: phenocode.id) do
          nil -> %StatsSex{}
          stats -> stats
        end
        |> StatsSex.changeset(%{
          phenocode_id: phenocode.id,
          sex: 2,
          case_fatality: female_case_fatality,
          mean_age: female_mean_age,
          median_reoccurence: female_median_reoccurence,
          n_individuals: female_nindivs,
          prevalence: female_nindivs / total_females,
          reoccurence_rate: female_reoccurence_rate
        })
        |> Repo.insert_or_update()

      case result_female_stats do
        {:ok, _} ->
          Logger.debug("insert ok for #{name} - female")

        {:error, changeset} ->
          Logger.warn(inspect(changeset))
      end

      # Create stats table for sex=male
      male_case_fatality =
        data |> Map.get("common_stats", %{}) |> Map.get("male", %{}) |> Map.get("case_fatality")

      male_nindivs =
        data |> Map.get("common_stats", %{}) |> Map.get("male", %{}) |> Map.get("nindivs")

      male_mean_age =
        data |> Map.get("common_stats", %{}) |> Map.get("male", %{}) |> Map.get("mean_age")

      male_median_reoccurence =
        data
        |> Map.get("longit", %{})
        |> Map.get("male", %{})
        |> Map.get("median_count")

      male_median_reoccurence =
        if not is_nil(male_median_reoccurence) do
          trunc(male_median_reoccurence)
        end

      male_reoccurence_rate =
        data |> Map.get("longit", %{}) |> Map.get("male", %{}) |> Map.get("perc_hosp")

      result_male_stats =
        case Repo.get_by(StatsSex, sex: 1, phenocode_id: phenocode.id) do
          nil -> %StatsSex{}
          stats -> stats
        end
        |> StatsSex.changeset(%{
          phenocode_id: phenocode.id,
          sex: 1,
          case_fatality: male_case_fatality,
          mean_age: male_mean_age,
          median_reoccurence: male_median_reoccurence,
          n_individuals: male_nindivs,
          prevalence: male_nindivs / total_males,
          reoccurence_rate: male_reoccurence_rate
        })
        |> Repo.insert_or_update()

      case result_male_stats do
        {:ok, _} ->
          Logger.debug("insert ok for #{name} - male")

        {:error, changeset} ->
          Logger.warn(inspect(changeset))
      end
  end
end)
