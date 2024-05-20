defmodule Risteys.LabTestStats do
  @moduledoc """
  The LabTestStats context.
  """

  import Ecto.Query, warn: false
  alias Risteys.Repo
  alias Risteys.OMOP
  alias Risteys.LabTestStats.NPeople
  alias Risteys.LabTestStats.MedianNMeasurements
  alias Risteys.LabTestStats.MedianNDaysFirstToLastMeasurement
  alias Risteys.LabTestStats.DistributionsLabValues

  require Logger

  @doc """
  Takes a tree of OMOP lab tests and attach stats to it.
  """
  def merge_stats(lab_tests_tree) do
    # TODO(Vincent 2024-05-16)
    # Could this be just done on the database side?
    npeople_empty_stats = %{
      npeople_male: nil,
      npeople_female: nil,
      npeople_total: nil,
      sex_female_percent: nil
    }

    median_n_measurements_empty_stats = %{
      median_n_measurements: nil
    }

    median_ndays_first_to_last_measurement_empty_stats = %{
      median_ndays_first_to_last_measurement: nil
    }

    npeople_stats = get_stats_npeople()
    median_n_measurements_stats = get_stats_median_n_measurements()

    median_ndays_first_to_last_measurement_stats =
      get_stats_median_ndays_first_to_last_measurement()

    for %{lab_tests: lab_tests} = rec <- lab_tests_tree do
      with_stats =
        for lab_test <- lab_tests do
          lab_test
          |> Map.merge(Map.get(npeople_stats, lab_test.lab_test_concept_id, npeople_empty_stats))
          |> Map.merge(
            Map.get(
              median_n_measurements_stats,
              lab_test.lab_test_concept_id,
              median_n_measurements_empty_stats
            )
          )
          |> Map.merge(
            Map.get(
              median_ndays_first_to_last_measurement_stats,
              lab_test.lab_test_concept_id,
              median_ndays_first_to_last_measurement_empty_stats
            )
          )
        end
        |> Enum.sort_by(
          fn stats -> stats.npeople_total end,
          RisteysWeb.Utils.sorter_nil_is_0(:desc)
        )

      %{rec | lab_tests: with_stats}
    end
  end

  def get_overall_stats() do
    %{
      npeople: get_overall_stats_npeople(),
      median_n_measurements: get_overall_stats_median_n_measurements(),
      median_ndays_first_to_last_measurement:
        get_overall_stats_median_ndays_first_to_last_measurement()
    }
  end

  defp get_overall_stats_npeople() do
    Repo.one(
      from npeople_stats in NPeople,
        left_join: omop_concept in OMOP.Concept,
        on: npeople_stats.omop_concept_dbid == omop_concept.id,
        select:
          max(coalesce(npeople_stats.female_count, 0) + coalesce(npeople_stats.male_count, 0))
    )
  end

  defp get_overall_stats_median_n_measurements() do
    Repo.one(
      from stats in MedianNMeasurements,
        select: max(stats.median_n_measurements)
    )
  end

  defp get_overall_stats_median_ndays_first_to_last_measurement() do
    Repo.one(
      from stats in MedianNDaysFirstToLastMeasurement,
        select: max(stats.median_ndays_first_to_last_measurement)
    )
  end

  @doc """
  Reset all the lab test stats for N People using data from file.
  """
  def import_stats_npeople(file_path) do
    omop_ids = OMOP.get_map_omop_ids()

    stats =
      file_path
      |> File.stream!()
      |> CSV.decode!(headers: true)
      |> Stream.filter(fn %{"OMOP_ID" => omop_concept_id} ->
        case Map.has_key?(omop_ids, omop_concept_id) do
          true ->
            true

          false ->
            Logger.warning(
              "Discarding N People stats for omop_concept_id=#{omop_concept_id}: OMOP concept ID not found in database."
            )

            false
        end
      end)

      # Group NPeople stats by OMOP concept ID
      |> Enum.reduce(%{}, fn row, acc ->
        %{
          "OMOP_ID" => omop_concept_id,
          "Sex" => sex,
          "NPeople" => npeople
        } = row

        npeople = String.to_integer(npeople)

        empty_counts = %{female_count: nil, male_count: nil}
        counts = Map.get(acc, omop_concept_id, empty_counts)

        new_counts =
          case sex do
            "female" ->
              %{counts | female_count: npeople}

            "male" ->
              %{counts | male_count: npeople}

            other ->
              Logger.warning("Got unexpected value while parsing row: Sex=\"#{other}\"")
              counts
          end

        Map.put(acc, omop_concept_id, new_counts)
      end)
      |> Enum.map(fn {omop_concept_id, %{female_count: female_count, male_count: male_count}} ->
        omop_concept_dbid = Map.fetch!(omop_ids, omop_concept_id)

        %{
          omop_concept_dbid: omop_concept_dbid,
          female_count: female_count,
          male_count: male_count
        }
      end)

    Repo.transaction(fn ->
      Repo.delete_all(NPeople)

      Enum.each(stats, &create_stats_npeople/1)
    end)
  end

  defp create_stats_npeople(attrs) do
    %NPeople{}
    |> NPeople.changeset(attrs)
    |> Repo.insert!()
  end

  # Returns a map of OMOP Concept ID => N People stats
  defp get_stats_npeople() do
    Repo.all(
      from npeople in NPeople,
        left_join: omop_concept in OMOP.Concept,
        on: npeople.omop_concept_dbid == omop_concept.id,
        select: {
          omop_concept.concept_id,
          %{npeople_female: npeople.female_count, npeople_male: npeople.male_count}
        }
    )
    |> Enum.reduce(%{}, fn {omop_concept_id, lab_test_stats}, acc ->
      npeople_total = (lab_test_stats.npeople_male || 0) + (lab_test_stats.npeople_female || 0)

      sex_female_percent = 100 * (lab_test_stats.npeople_female || 0) / npeople_total

      lab_test_stats =
        lab_test_stats
        |> Map.merge(%{
          npeople_total: npeople_total,
          sex_female_percent: sex_female_percent
        })

      Map.put(acc, omop_concept_id, lab_test_stats)
    end)
  end

  # Return a map of lab test OMOP concept ID => Median N mesurements stats
  defp get_stats_median_n_measurements() do
    Repo.all(
      from stat in MedianNMeasurements,
        left_join: lab_test in OMOP.Concept,
        on: stat.omop_concept_dbid == lab_test.id,
        select: {
          lab_test.concept_id,
          %{median_n_measurements: stat.median_n_measurements}
        }
    )
    |> Enum.into(%{})
  end

  defp get_stats_median_ndays_first_to_last_measurement() do
    Repo.all(
      from stat in MedianNDaysFirstToLastMeasurement,
        left_join: lab_test in OMOP.Concept,
        on: stat.omop_concept_dbid == lab_test.id,
        select: {
          lab_test.concept_id,
          %{median_ndays_first_to_last_measurement: stat.median_ndays_first_to_last_measurement}
        }
    )
    |> Enum.into(%{})
  end

  @doc """
  Reset all the stats for median N measurements using data from file.
  """
  def import_stats_median_n_measurements(file_path) do
    omop_ids = OMOP.get_map_omop_ids()

    stats =
      file_path
      |> File.stream!()
      |> CSV.decode!(headers: true)
      |> Stream.filter(fn %{"OMOP_ID" => omop_concept_id} ->
        case Map.has_key?(omop_ids, omop_concept_id) do
          true ->
            true

          false ->
            Logger.warning(
              "Discarding median N measurements stats for omop_concept_id=#{omop_concept_id}: OMOP concept ID not found in database."
            )

            false
        end
      end)
      |> Enum.map(fn row ->
        %{
          "OMOP_ID" => omop_concept_id,
          "MedianNMeasurementsPerPerson" => median_n_measurements,
          "NPeople" => npeople
        } = row

        lab_test_dbid = Map.fetch!(omop_ids, omop_concept_id)

        %{
          omop_concept_dbid: lab_test_dbid,
          median_n_measurements: median_n_measurements,
          npeople: npeople
        }
      end)

    Repo.transaction(fn ->
      Repo.delete_all(MedianNMeasurements)

      Enum.each(stats, &create_stats_median_n_measurements/1)
    end)
  end

  defp create_stats_median_n_measurements(attrs) do
    %MedianNMeasurements{}
    |> MedianNMeasurements.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Reset all the median N days from first to last measurement stats from a file.
  """
  def import_stats_median_ndays_first_to_last(file_path) do
    omop_ids = OMOP.get_map_omop_ids()

    stats =
      file_path
      |> File.stream!()
      |> CSV.decode!(headers: true)
      |> Stream.filter(fn %{"OMOP_ID" => omop_concept_id} ->
        case Map.has_key?(omop_ids, omop_concept_id) do
          true ->
            true

          false ->
            Logger.warning(
              "Discarding median N days stats for omop_concept_id=#{omop_concept_id}: OMOP concept ID not found in database."
            )

            false
        end
      end)
      |> Enum.map(fn row ->
        %{
          "OMOP_ID" => omop_concept_id,
          "MedianDurationDaysFirstToLast" => median_ndays,
          "NPeopleAfterFilterOut" => npeople
        } = row

        lab_test_dbid = Map.fetch!(omop_ids, omop_concept_id)

        %{
          omop_concept_dbid: lab_test_dbid,
          median_ndays_first_to_last_measurement: median_ndays,
          npeople: npeople
        }
      end)

    Repo.transaction(fn ->
      Repo.delete_all(MedianNDaysFirstToLastMeasurement)

      Enum.each(stats, &create_stats_median_ndays_first_to_last_measurement/1)
    end)
  end

  defp create_stats_median_ndays_first_to_last_measurement(attrs) do
    %MedianNDaysFirstToLastMeasurement{}
    |> MedianNDaysFirstToLastMeasurement.changeset(attrs)
    |> Repo.insert!()
  end

  def get_single_lab_test_stats(omop_id) do
    Repo.one(
      from lab_test in OMOP.Concept,
        # N people
        full_join: npeople in NPeople,
        on: lab_test.id == npeople.omop_concept_dbid,
        # Median N measurements / person
        full_join: median_n_measurements in MedianNMeasurements,
        on: lab_test.id == median_n_measurements.omop_concept_dbid,
        # Median duration from first to last measurement
        full_join: median_duration in MedianNDaysFirstToLastMeasurement,
        on: lab_test.id == median_duration.omop_concept_dbid,
        # Distribution of lab values
        full_join: distribution_lab_values in DistributionsLabValues,
        on: lab_test.id == distribution_lab_values.omop_concept_dbid,
        where: lab_test.concept_id == ^omop_id,
        select: %{
          omop_concept_id: ^omop_id,
          name: lab_test.concept_name,
          median_n_measurements: median_n_measurements.median_n_measurements,
          npeople_female: npeople.female_count,
          npeople_male: npeople.male_count,
          npeople_both_sex: coalesce(npeople.female_count, 0) + coalesce(npeople.male_count, 0),
          median_ndays_first_to_last_measurement:
            median_duration.median_ndays_first_to_last_measurement,
          distributions_lab_values: distribution_lab_values.distributions
        }
    )
  end

  @doc """
  Reset all the lab value distributions from files.

  `stats_file_path` format should be CSV with the following columns:
  - OMOP_ID
  - LAB_UNIT
  - Bin
  - NRecords
  - NPeople

  `breaks_file_path` format should be newline-delimited JSON, each line having
  the columns:
  - omop_id
  - lab_unit
  - breaks
  """
  def import_stats_distribution_lab_values(stats_file_path, breaks_file_path) do
    omop_ids = OMOP.get_map_omop_ids()

    bins_map =
      stats_file_path
      |> File.stream!()
      |> CSV.decode!(headers: true)
      |> Stream.reject(fn %{"OMOP_ID" => omop_concept_id} -> omop_concept_id == "NA" end)
      # Discard rows that are related to an OMOP Concept ID we don't have in the DB.
      # This assumes that the OMOP concept ID have been imported already.
      |> Enum.reduce({MapSet.new(), []}, fn %{"OMOP_ID" => omop_concept_id} = row, {seen, rows} ->
        case {Map.has_key?(omop_ids, omop_concept_id), MapSet.member?(seen, omop_concept_id)} do
          {true, _} ->
            {seen, [row | rows]}

          {false, true} ->
            {seen, rows}

          {false, false} ->
            Logger.warning(
              "Discarding all rows for lab value distribution for omop_concept_id=#{omop_concept_id}: OMOP concept ID not found in database."
            )

            {MapSet.put(seen, omop_concept_id), rows}
        end
      end)
      |> (fn {_seen, rows} -> rows end).()
      # Collect bins for each unique {OMOP_ID, LAB_UNIT}
      # Data structure of the accumulator:
      #   %{
      #     {"omop id 1", "meas unit 1"} => [
      #       {bin: "bin 1", npeople: Int, nrecords: Int},
      #       ...
      #     ],
      #     ...
      #   }
      |> Enum.reduce(%{}, fn row, acc ->
        %{
          "OMOP_ID" => omop_concept_id,
          "LAB_UNIT" => measurement_unit,
          "Bin" => bin,
          "NRecords" => nrecords,
          "NPeople" => npeople
        } = row

        key = {omop_concept_id, measurement_unit}
        existing_bins = Map.get(acc, key, [])

        bin = %{"bin" => bin, "npeople" => npeople, "nrecords" => nrecords}

        new_bins = [bin | existing_bins]
        Map.put(acc, key, new_bins)
      end)

    breaks_map =
      breaks_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      # Collect breaks, group by {omop id, lab unit}.
      |> Enum.reduce(%{}, fn row, acc ->
        %{
          "omop_id" => omop_id,
          "breaks" => breaks,
          "lab_unit" => measurement_unit
        } = row

        breaks = Enum.map(breaks, &to_string/1)

        Map.put(acc, {omop_id, measurement_unit}, breaks)
      end)

    # Merging bins and breaks.
    # If some bins don't have associated breaks, then we put an empty break
    # list, because we still want to keep the bins.
    # If some breaks don't have associated bins, then they are silently
    # discarded.
    distributions_map =
      Enum.reduce(bins_map, %{}, fn {{omop_concept_id, measurement_unit} = key, dist_bins}, acc ->
        dist_breaks =
          case Map.get(breaks_map, key) do
            nil ->
              Logger.warning(
                "Data for omop_concept_id=#{omop_concept_id}, measurement_unit=#{measurement_unit} doesn't have any associated breaks. Adding empty breaks."
              )

              []

            dist_breaks ->
              dist_breaks
          end

        Map.put(acc, key, %{bins: dist_bins, breaks: dist_breaks})
      end)

    # Ungroup the distributions by measurement unit. Only leave the OMOP ID as key.
    grouped_by_omop_id =
      Enum.reduce(distributions_map, %{}, fn {key, value}, acc ->
        {omop_concept_id, measurement_unit} = key
        %{bins: dist_bins, breaks: dist_breaks} = value

        distribution = %{
          "measurement_unit" => measurement_unit,
          "bins" => dist_bins,
          "breaks" => dist_breaks
        }

        existing_distributions = Map.get(acc, omop_concept_id, %{})
        new_distributions = Map.put(existing_distributions, measurement_unit, distribution)

        Map.put(acc, omop_concept_id, new_distributions)
      end)

    attrs_list =
      Enum.map(grouped_by_omop_id, fn {omop_concept_id, distributions} ->
        distributions = Map.values(distributions)
        omop_concept_dbid = Map.fetch!(omop_ids, omop_concept_id)

        %{
          omop_concept_dbid: omop_concept_dbid,
          distributions: distributions
        }
      end)

    Repo.transaction(fn ->
      Repo.delete_all(DistributionsLabValues)

      Enum.each(attrs_list, &create_stats_distribution_lab_values/1)
    end)
  end

  defp create_stats_distribution_lab_values(attrs) do
    %DistributionsLabValues{}
    |> DistributionsLabValues.changeset(attrs)
    |> Repo.insert!()
  end
end
