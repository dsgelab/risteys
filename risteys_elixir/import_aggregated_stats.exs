# Import pre-processed / aggregated data in the database
#
# Usage:
#     mix run import_aggregated_data.exs <json-file-aggregegated-stats>

alias Risteys.{Repo, Phenocode, StatsSex}
import Ecto.Query
require Logger

Logger.configure(level: :debug)
[filepath | _] = System.argv()

# taken from the number of records in FINNGEN_PHENOTYPES_R3_V1.txt
total_indivs = 152_796

filepath
|> File.read!()
|> Jason.decode!()
|> Enum.each(fn {name, data} ->
  Logger.debug("processing #{name}")

  phenocode = Repo.one(from p in Phenocode, where: p.name == ^name)

  cond do
    is_nil(Map.get(data, "common_stats")) ->
      Logger.warn("Skipping #{name}: no common_stats")

    is_nil(phenocode) ->
      Logger.warn("Skipping. #{name} not in DB")

    true ->
      # Update phenocode with stats distributions
      year_distrib = Map.get(data, "year_distrib")
      age_distrib = Map.get(data, "age_distrib")
      Logger.debug("year_distrib: #{inspect(year_distrib)}")
      Logger.debug("age_distrib: #{inspect(age_distrib)}")

      changeset =
        Ecto.Changeset.change(phenocode, distrib_year: year_distrib, distrib_age: age_distrib)

      Logger.debug("Applying Phenocode changeset: #{inspect(changeset)}")
      phenocode = Repo.update!(changeset)

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

      all_stats =
        StatsSex.changeset(
          %StatsSex{},
          %{
            phenocode_id: phenocode.id,
            sex: 0,
            case_fatality: all_case_fatality,
            mean_age: all_mean_age,
            median_reoccurence: all_median_reoccurence,
            n_individuals: all_nindivs,
            prevalence: all_nindivs / total_indivs,
            reoccurence_rate: all_reoccurence_rate
          }
        )

      if all_stats.valid? do
        Repo.insert!(all_stats)
      else
        Logger.warn(inspect(all_stats.errors))
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

      female_stats =
        StatsSex.changeset(
          %StatsSex{},
          %{
            phenocode_id: phenocode.id,
            sex: 2,
            case_fatality: female_case_fatality,
            mean_age: female_mean_age,
            median_reoccurence: female_median_reoccurence,
            n_individuals: female_nindivs,
            prevalence: female_nindivs / total_indivs,
            reoccurence_rate: female_reoccurence_rate
          }
        )

      if female_stats.valid? do
        Repo.insert!(female_stats)
      else
        Logger.warn(inspect(female_stats.errors))
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

      male_stats =
        StatsSex.changeset(
          %StatsSex{},
          %{
            phenocode_id: phenocode.id,
            sex: 1,
            case_fatality: male_case_fatality,
            mean_age: male_mean_age,
            median_reoccurence: male_median_reoccurence,
            n_individuals: male_nindivs,
            prevalence: male_nindivs / total_indivs,
            reoccurence_rate: male_reoccurence_rate
          }
        )

      if male_stats.valid? do
        Repo.insert!(male_stats)
      else
        Logger.warn(inspect(male_stats.errors))
      end
  end
end)
