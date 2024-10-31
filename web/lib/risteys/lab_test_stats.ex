defmodule Risteys.LabTestStats do
  @moduledoc """
  The LabTestStats context.
  """

  import Ecto.Query, warn: false
  alias Risteys.Repo
  alias Risteys.OMOP
  alias Risteys.LabTestStats.DatasetMetadata
  alias Risteys.LabTestStats.NPeople
  alias Risteys.LabTestStats.MedianNMeasurements
  alias Risteys.LabTestStats.PeopleWithTwoPlusRecords
  alias Risteys.LabTestStats.MedianYearsFirstToLastMeasurement
  alias Risteys.LabTestStats.QCTable
  alias Risteys.LabTestStats.DistributionLabValues
  alias Risteys.LabTestStats.DistributionYearOfBirth
  alias Risteys.LabTestStats.DistributionAgeFirstMeasurement
  alias Risteys.LabTestStats.DistributionAgeLastMeasurement
  alias Risteys.LabTestStats.DistributionAgeStartOfRegistry
  alias Risteys.LabTestStats.DistributionNYearsFirstToLastMeasurement
  alias Risteys.LabTestStats.DistributionNMeasurementsOverYears
  alias Risteys.LabTestStats.DistributionNMeasurementsPerPerson
  alias Risteys.LabTestStats.DistributionValueRangePerPerson

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

    percent_people_two_plus_records_empty_stats = %{
      percent_people_two_plus_records: nil
    }

    median_years_first_to_last_measurement_empty_stats = %{
      median_years_first_to_last_measurement: nil
    }

    npeople_stats = get_stats_npeople()

    percent_people_two_plus_records = get_stats_percent_people_two_plus_records()

    median_years_first_to_last_measurement_stats =
      get_stats_median_years_first_to_last_measurement()

    for %{lab_tests: lab_tests} = rec <- lab_tests_tree do
      with_stats =
        for lab_test <- lab_tests do
          lab_test
          |> Map.merge(Map.get(npeople_stats, lab_test.lab_test_concept_id, npeople_empty_stats))
          |> Map.merge(
            Map.get(
              percent_people_two_plus_records,
              lab_test.lab_test_concept_id,
              percent_people_two_plus_records_empty_stats
            )
          )
          |> Map.merge(
            Map.get(
              median_years_first_to_last_measurement_stats,
              lab_test.lab_test_concept_id,
              median_years_first_to_last_measurement_empty_stats
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
      median_years_first_to_last_measurement:
        get_overall_stats_median_years_first_to_last_measurement(),
      percent_people_two_plus_records: get_overall_stats_percent_people_two_plus_records()
    }
  end

  defp get_overall_stats_npeople() do
    Repo.one(DatasetMetadata).npeople_alive
  end

  defp get_overall_stats_median_years_first_to_last_measurement() do
    Repo.one(
      from stats in MedianYearsFirstToLastMeasurement,
        select: max(stats.median_years_first_to_last_measurement)
    )
  end

  defp get_overall_stats_percent_people_two_plus_records() do
    Repo.one(
      from stats in PeopleWithTwoPlusRecords,
        select: max(stats.percent_people)
    )
  end

  def import_dataset_metadata(file_path) do
    data =
      file_path
      |> File.read!()
      |> Jason.decode!()

    %{"NPeople" => npeople_alive} = data

    attrs = %{npeople_alive: npeople_alive}

    {:ok, _} =
      Repo.transaction(fn ->
        Repo.delete_all(DatasetMetadata)

        %DatasetMetadata{}
        |> DatasetMetadata.changeset(attrs)
        |> Repo.insert!()
      end)
  end

  @doc """
  Reset all the lab test stats for N People using data from file.
  """
  def import_stats_npeople(file_path) do
    omop_ids = OMOP.get_map_omop_ids()

    stats =
      file_path
      |> File.stream!(line_or_bytes: :line)
      |> Stream.map(&Jason.decode!/1)
      |> Stream.filter(fn %{"OMOP_CONCEPT_ID" => omop_concept_id} ->
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
          "OMOP_CONCEPT_ID" => omop_concept_id,
          "Sex" => sex,
          "NPeople" => npeople
        } = row

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

  # Returns a map of OMOP Concept ID => Percent people with 2+ records
  defp get_stats_percent_people_two_plus_records() do
    Repo.all(
      from stat in PeopleWithTwoPlusRecords,
        left_join: omop_concept in OMOP.Concept,
        on: stat.omop_concept_dbid == omop_concept.id,
        select: {
          omop_concept.concept_id,
          %{
            percent_people_two_plus_records: stat.percent_people
          }
        }
    )
    |> Enum.into(%{})
  end

  defp get_stats_median_years_first_to_last_measurement() do
    Repo.all(
      from stat in MedianYearsFirstToLastMeasurement,
        left_join: lab_test in OMOP.Concept,
        on: stat.omop_concept_dbid == lab_test.id,
        select: {
          lab_test.concept_id,
          %{median_years_first_to_last_measurement: stat.median_years_first_to_last_measurement}
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
      |> Stream.map(&Jason.decode!/1)
      |> Stream.filter(fn %{"OMOP_CONCEPT_ID" => omop_concept_id} ->
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
          "OMOP_CONCEPT_ID" => omop_concept_id,
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
  Reset all stats of people with 2+ records to data from a file.
  """
  def import_stats_people_with_two_plus_records(file_path) do
    omop_ids = OMOP.get_map_omop_ids()

    stats =
      file_path
      |> File.stream!(line_or_bytes: :lines)
      |> Stream.map(&Jason.decode!/1)
      |> Stream.filter(fn %{"OMOP_CONCEPT_ID" => omop_concept_id} ->
        case Map.has_key?(omop_ids, omop_concept_id) do
          true ->
            true

          false ->
            Logger.warning(
              "Discarding stats people with 2+ records for omop_concept_id=#{omop_concept_id}: OMOP concept ID not found in database."
            )

            false
        end
      end)
      |> Enum.map(fn row ->
        %{
          "OMOP_CONCEPT_ID" => omop_concept_id,
          "PercentagePeopleWithTwoOrMoreRecords" => percent_people,
          "NPeople" => npeople
        } = row

        omop_concept_dbid = Map.fetch!(omop_ids, omop_concept_id)

        %{
          omop_concept_dbid: omop_concept_dbid,
          percent_people: percent_people,
          npeople: npeople
        }
      end)

    Repo.transaction(fn ->
      Repo.delete_all(PeopleWithTwoPlusRecords)

      Enum.each(stats, &create_stats_people_with_two_plus_records/1)
    end)
  end

  defp create_stats_people_with_two_plus_records(attrs) do
    %PeopleWithTwoPlusRecords{}
    |> PeopleWithTwoPlusRecords.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Reset all the median duration (years) from first to last measurement stats from a file.
  """
  def import_stats_median_years_first_to_last(file_path) do
    omop_ids = OMOP.get_map_omop_ids()

    stats =
      file_path
      |> File.stream!(line_or_bytes: :line)
      |> Stream.map(&Jason.decode!/1)
      |> Stream.filter(fn %{"OMOP_CONCEPT_ID" => omop_concept_id} ->
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
          "OMOP_CONCEPT_ID" => omop_concept_id,
          "MedianDurationYearsFirstToLast" => median_years,
          "NPeople" => npeople
        } = row

        lab_test_dbid = Map.fetch!(omop_ids, omop_concept_id)

        %{
          omop_concept_dbid: lab_test_dbid,
          median_years_first_to_last_measurement: median_years,
          npeople: npeople
        }
      end)

    Repo.transaction(fn ->
      Repo.delete_all(MedianYearsFirstToLastMeasurement)

      Enum.each(stats, &create_stats_median_years_first_to_last_measurement/1)
    end)
  end

  defp create_stats_median_years_first_to_last_measurement(attrs) do
    %MedianYearsFirstToLastMeasurement{}
    |> MedianYearsFirstToLastMeasurement.changeset(attrs)
    |> Repo.insert!()
  end

  def get_single_lab_test_stats(omop_id) do
    stats =
      Repo.one(
        from lab_test in OMOP.Concept,
          # N people
          full_join: npeople in NPeople,
          on: lab_test.id == npeople.omop_concept_dbid,

          # People with 2+ records
          full_join: people_with_two_plus_records in PeopleWithTwoPlusRecords,
          on: lab_test.id == people_with_two_plus_records.omop_concept_dbid,

          # Median N measurements / person
          full_join: median_n_measurements in MedianNMeasurements,
          on: lab_test.id == median_n_measurements.omop_concept_dbid,

          # Median duration from first to last measurement
          full_join: median_duration in MedianYearsFirstToLastMeasurement,
          on: lab_test.id == median_duration.omop_concept_dbid,

          # Distribution of lab values
          full_join: distribution_lab_values in DistributionLabValues,
          on: lab_test.id == distribution_lab_values.omop_concept_dbid,

          # Distribution of year of birth
          full_join: distribution_year_of_birth in DistributionYearOfBirth,
          on: lab_test.id == distribution_year_of_birth.omop_concept_dbid,

          # Distribution of age at first measurement
          full_join: distribution_age_first_measurement in DistributionAgeFirstMeasurement,
          on: lab_test.id == distribution_age_first_measurement.omop_concept_dbid,

          # Distribution of age at last measurement
          full_join: distribution_age_last_measurement in DistributionAgeLastMeasurement,
          on: lab_test.id == distribution_age_last_measurement.omop_concept_dbid,

          # Distribution of age at start of registry
          full_join: distribution_age_start_of_registry in DistributionAgeStartOfRegistry,
          on: lab_test.id == distribution_age_start_of_registry.omop_concept_dbid,

          # Distribution of duration from first to last measurement
          full_join:
            distribution_nyears_first_to_last_measurement in DistributionNYearsFirstToLastMeasurement,
          on: lab_test.id == distribution_nyears_first_to_last_measurement.omop_concept_dbid,

          # Distribution N measurements over the years
          full_join: distribution_n_measurements_over_years in DistributionNMeasurementsOverYears,
          on: lab_test.id == distribution_n_measurements_over_years.omop_concept_dbid,

          # Distribution N measurements per person
          full_join: distribution_n_measurements_per_person in DistributionNMeasurementsPerPerson,
          on: lab_test.id == distribution_n_measurements_per_person.omop_concept_dbid,

          # Distribution value range per person
          full_join: distribution_value_range_per_person in DistributionValueRangePerPerson,
          on: lab_test.id == distribution_value_range_per_person.omop_concept_dbid,
          where: lab_test.concept_id == ^omop_id,
          select: %{
            omop_concept_id: ^omop_id,
            name: lab_test.concept_name,
            percent_people_two_plus_records: people_with_two_plus_records.percent_people,
            median_n_measurements: median_n_measurements.median_n_measurements,
            npeople_female: npeople.female_count,
            npeople_male: npeople.male_count,
            median_years_first_to_last_measurement:
              median_duration.median_years_first_to_last_measurement,
            distribution_lab_values: distribution_lab_values,
            distribution_year_of_birth: distribution_year_of_birth.distribution,
            distribution_age_first_measurement: distribution_age_first_measurement.distribution,
            distribution_age_last_measurement: distribution_age_last_measurement.distribution,
            distribution_age_start_of_registry: distribution_age_start_of_registry.distribution,
            distribution_nyears_first_to_last_measurement:
              distribution_nyears_first_to_last_measurement.distribution,
            distribution_n_measurements_over_years:
              distribution_n_measurements_over_years.distribution,
            distribution_n_measurements_per_person:
              distribution_n_measurements_per_person.distribution,
            distribution_value_range_per_person: distribution_value_range_per_person.distribution
          }
      )

    npeople_both_sex =
      case {stats.npeople_female, stats.npeople_male} do
        {nil, nil} ->
          nil

        {nil, nmale} ->
          nmale

        {nfemale, nil} ->
          nfemale

        {nfemale, nmale} ->
          nfemale + nmale
      end

    stats = Map.put_new(stats, :npeople_both_sex, npeople_both_sex)

    sex_female_percent =
      if is_nil(stats.npeople_female) or is_nil(stats.npeople_both_sex) do
        nil
      else
        (100 * stats.npeople_female / stats.npeople_both_sex)
        |> RisteysWeb.Utils.pretty_number()
      end

    stats = Map.put_new(stats, :sex_female_percent, sex_female_percent)

    qc_table = get_qc_table(omop_id)

    # TODO(Vincent 2024-10-23) ::WIP_DIST_LAB_VALUE
    # Temporarily deactivated following code while working on the distribution of lab values:

    # distribution_n_measurements_over_years =
    #   stats.distribution_n_measurements_over_years
    #   |> rebuild_year_month_distribution()

    # distribution_n_measurements_per_person =
    #   stats.distribution_n_measurements_per_person
    #   |> rebuild_n_measurements_per_person_distribution()

    # distribution_value_range_per_person =
    #   stats.distribution_value_range_per_person
    #   |> rebuild_distribution(%{"range" => :range, "npeople" => :npeople}, %{npeople: 0})

    %{
      stats
      | distribution_lab_values: stats.distribution_lab_values,
        distribution_year_of_birth: stats.distribution_year_of_birth,
        distribution_age_first_measurement: stats.distribution_age_first_measurement,
        distribution_age_last_measurement: stats.distribution_age_last_measurement,
        distribution_age_start_of_registry: stats.distribution_age_start_of_registry,
        distribution_nyears_first_to_last_measurement:
          stats.distribution_nyears_first_to_last_measurement

        # TODO(Vincent 2024-10-23) ::WIP_DIST_LAB_VALUE
        # distribution_n_measurements_over_years: distribution_n_measurements_over_years,
        # distribution_n_measurements_per_person: distribution_n_measurements_per_person,
        # distribution_value_range_per_person: distribution_value_range_per_person
    }
    |> Map.put_new(:qc_table, qc_table)
  end

  def import_qc_tables(
        qc_tables_stats_file_path,
        qc_tables_dist_values_stats_file_path,
        qc_tables_dist_bins_definitions_file_path,
        qc_tables_test_outcome_counts_file_path
      ) do
    map_stats = scan_qc_tables_stats(qc_tables_stats_file_path)

    map_distribution_measurement_values =
      scan_qc_tables_distribution_measurement_values(
        qc_tables_dist_values_stats_file_path,
        qc_tables_dist_bins_definitions_file_path
      )

    map_test_outcome_counts = scan_qc_tables_test_outcome(qc_tables_test_outcome_counts_file_path)

    map_omop_dbids = OMOP.get_map_omop_ids()

    attrs_list =
      for {key, stats} <- map_stats do
        {omop_id, test_name, measurement_unit} = key

        omop_concept_dbid = Map.get(map_omop_dbids, omop_id)

        distribution = Map.get(map_distribution_measurement_values, key)
        test_outcome_counts = Map.get(map_test_outcome_counts, key)

        Map.merge(stats, %{
          omop_concept_dbid: omop_concept_dbid,
          omop_id: omop_id,
          test_name: test_name,
          measurement_unit: measurement_unit,
          test_outcome_counts: test_outcome_counts,
          distribution_measurement_values: distribution
        })
      end
      |> Enum.filter(fn %{omop_concept_dbid: omop_concept_dbid, omop_id: omop_id} ->
        if is_nil(omop_concept_dbid) do
          Logger.warning(
            "Discarding stats for QC table for OMOP Concept ID: #{omop_id}: OMOP concept ID not found in the database."
          )

          false
        else
          true
        end
      end)

    {:ok, :ok} =
      Repo.transaction(fn ->
        Repo.delete_all(QCTable)

        Enum.each(attrs_list, fn attrs ->
          %QCTable{}
          |> QCTable.changeset(attrs)
          |> Repo.insert!()
        end)
      end)
  end

  defp scan_qc_tables_stats(file_path) do
    file_path
    |> File.stream!()
    |> Stream.map(&Jason.decode!/1)
    |> Enum.reduce(%{}, fn row, acc ->
      %{
        "OMOP_CONCEPT_ID" => omop_id,
        "TEST_NAME" => test_name,
        "MEASUREMENT_UNIT" => measurement_unit,
        "MEASUREMENT_UNIT_HARMONIZED" => measurement_unit_harmonized,
        "NRecords" => nrecords,
        "NPeople" => npeople,
        "PercentMissingMeasurementValue" => percent_missing_measurement_value
      } = row

      key = {omop_id, test_name, measurement_unit}

      value = %{
        measurement_unit_harmonized: measurement_unit_harmonized,
        nrecords: nrecords,
        npeople: npeople,
        percent_missing_measurement_value: percent_missing_measurement_value
      }

      Map.put_new(acc, key, value)
    end)
  end

  defp scan_qc_tables_test_outcome(file_path) do
    file_path
    |> File.stream!()
    |> Stream.map(&Jason.decode!/1)
    |> Enum.reduce(%{}, fn row, acc ->
      %{
        "OMOP_CONCEPT_ID" => omop_id,
        "TEST_NAME" => test_name,
        "MEASUREMENT_UNIT" => measurement_unit,
        "TEST_OUTCOME" => test_outcome,
        "TestOutcomeCount" => count,
        "NPeople" => npeople
      } = row

      key = {omop_id, test_name, measurement_unit}
      new_count = %{test_outcome: test_outcome, count: count, npeople: npeople}
      list_counts = [new_count | Map.get(acc, key, [])]

      Map.put(acc, key, list_counts)
    end)
  end

  def scan_qc_tables_distribution_measurement_values(stats_file_path, bins_definitions_file_path) do
    map_stats =
      stats_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Enum.reduce(%{}, fn row, acc ->
        %{
          "OMOP_CONCEPT_ID" => omop_id,
          "TEST_NAME" => test_name,
          "MEASUREMENT_UNIT" => measurement_unit,
          "BinIndex" => bin_index,
          "NPeople" => npeople,
          "BinCount" => yy
        } = row

        # We use bin_index in the key to merge it with the bins definitions.
        # It will be dropped from the key after this merge.
        key = {omop_id, test_name, measurement_unit, bin_index}
        value = %{npeople: npeople, yy: yy}

        Map.put_new(acc, key, value)
      end)

    {map_bins_definitions, map_distribution_metadata} =
      bins_definitions_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Enum.reduce({%{}, %{}}, fn row, {acc_bins_definitions, acc_distribution_metadata} ->
        %{
          "OMOP_CONCEPT_ID" => omop_id,
          "BinIndex" => bin_index,
          "BreakMin" => break_min,
          "BreakMax" => break_max,
          "BinX1" => x1,
          "BinX2" => x2,
          "BinLabelX1" => x1_formatted,
          "BinLabelX2" => x2_formatted,
          "BinLabel" => x1x2_formatted
        } = row

        key_bins_definitions = {omop_id, bin_index}

        value_bins_definitions = %{
          x1: x1,
          x2: x2,
          x1_formatted: x1_formatted,
          x2_formatted: x2_formatted,
          x1x2_formatted: x1x2_formatted
        }

        key_distribution_metadata = omop_id

        value_distribution_metadata = %{
          break_min: break_min,
          break_max: break_max
        }

        {
          Map.put_new(acc_bins_definitions, key_bins_definitions, value_bins_definitions),
          Map.put(
            acc_distribution_metadata,
            key_distribution_metadata,
            value_distribution_metadata
          )
        }
      end)

    map_bins =
      for {stats_key, stats_value} <- map_stats, into: %{} do
        {omop_id, test_name, measurement_unit, bin_index} = stats_key

        key_bins_definitions = {omop_id, bin_index}

        value =
          map_bins_definitions
          |> Map.fetch!(key_bins_definitions)
          |> Map.merge(stats_value)

        {stats_key, value}
      end

    bins =
      Enum.reduce(map_bins, %{}, fn {key, value}, acc ->
        {omop_id, test_name, measurement_unit, _bin_index} = key

        new_key = {omop_id, test_name, measurement_unit}
        list_bins = [value | Map.get(acc, new_key, [])]

        Map.put(acc, new_key, list_bins)
      end)

    for {key, list_bins} <- bins, into: %{} do
      {omop_id, _test_name, measurement_unit} = key

      key_distribution_metadata = omop_id

      distribution_metadata =
        map_distribution_metadata
        |> Map.fetch!(key_distribution_metadata)
        |> Map.put_new(:measurement_unit, measurement_unit)

      {key, Map.put_new(distribution_metadata, :bins, list_bins)}
    end
  end

  def get_qc_table(omop_id) do
    Repo.all(
      from qc_row in QCTable,
        join: omop in OMOP.Concept,
        on: qc_row.omop_concept_dbid == omop.id,
        where: omop.concept_id == ^omop_id,
        order_by: [desc: :npeople],
        select: %{
          omop_id: omop.concept_id,
          test_name: qc_row.test_name,
          measurement_unit: qc_row.measurement_unit,
          measurement_unit_harmonized: qc_row.measurement_unit_harmonized,
          nrecords: qc_row.nrecords,
          npeople: qc_row.npeople,
          percent_missing_measurement_value: qc_row.percent_missing_measurement_value,
          test_outcome_counts: qc_row.test_outcome_counts,
          distribution_measurement_values: qc_row.distribution_measurement_values
        }
    )
  end

  @doc """
  Reset all the lab value distributions from files.

  `continuous_stats_file_path` is a JSONL file with the following keys:
  - OMOP_CONCEPT_ID
  - BinIndex
  - BinCount
  - NPeople

  `continuous_bins_definitions_file_path` is a JSONL file with the following keys:
  - OMOP_CONCEPT_ID
  - BinIndex
  - BinX1
  - BinX2
  - BinLabelX1
  - BinLabelX2
  - BinLabel
  - MEASUREMENT_UNIT_HARMONIZED
  - BreakMin
  - BreakMax

  `discrete_stats_file_path` is a JSONL file with the following keys:
  - MEASUREMENT_VALUE_HARMONIZED
  - BinCount
  - NPeople
  """
  def import_stats_distribution_lab_values(
        continuous_stats_file_path,
        continuous_bins_definitions_file_path,
        discrete_stats_file_path
      ) do
    attrs_list_continuous =
      import_stats_distributions_lab_values_continuous(
        continuous_stats_file_path,
        continuous_bins_definitions_file_path
      )

    attrs_list_discrete = import_stats_distributions_lab_values_discrete(discrete_stats_file_path)

    attrs_list_all = Enum.concat(attrs_list_continuous, attrs_list_discrete)

    {:ok, :ok} =
      Repo.transaction(fn ->
        Repo.delete_all(DistributionLabValues)

        Enum.each(attrs_list_all, &create_stats_distribution_lab_values/1)
      end)
  end

  # TODO(Vincent 2024-10-30)  Refactor the import stats distributions function to use a helper
  # function, since they basically all do the same thing:
  # - merging the bins definitions and the bins stats
  # - importing the data in the db

  defp import_stats_distributions_lab_values_continuous(
         continuous_stats_file_path,
         continuous_bins_definitions_file_path
       ) do
    omop_ids = OMOP.get_map_omop_ids()

    {map_xs, map_metadata} =
      continuous_bins_definitions_file_path
      |> File.stream!(:line)
      |> Stream.map(&Jason.decode!/1)
      |> Enum.reduce({%{}, %{}}, fn row, {acc_xs, acc_metadata} ->
        %{
          "OMOP_CONCEPT_ID" => omop_id,
          "BinIndex" => bin_index,
          "BinX1" => x1,
          "BinX2" => x2,
          "BinLabelX1" => x1_formatted,
          "BinLabelX2" => x2_formatted,
          "BinLabel" => x1x2_formatted,
          "MEASUREMENT_UNIT_HARMONIZED" => unit,
          "BreakMin" => break_min,
          "BreakMax" => break_max
        } = row

        bin_xs = %{
          x1: x1,
          x2: x2,
          x1_formatted: x1_formatted,
          x2_formatted: x2_formatted,
          x1x2_formatted: x1x2_formatted
        }

        acc_xs = Map.put_new(acc_xs, {omop_id, bin_index}, bin_xs)

        metadata = %{
          unit: unit,
          break_min: break_min,
          break_max: break_max
        }

        acc_metadata = Map.put(acc_metadata, omop_id, metadata)

        {acc_xs, acc_metadata}
      end)

    map_continuous_distributions =
      continuous_stats_file_path
      |> File.stream!(:line)
      |> Stream.map(&Jason.decode!/1)
      |> Enum.reduce(%{}, fn row, acc ->
        %{
          "OMOP_CONCEPT_ID" => omop_id,
          "BinIndex" => bin_index,
          "BinCount" => bin_count,
          "NPeople" => npeople
        } = row

        y_formatted = RisteysWeb.Utils.pretty_number(bin_count)

        bin =
          Map.fetch!(map_xs, {omop_id, bin_index})
          |> Map.merge(%{
            y: bin_count,
            y_formatted: y_formatted,
            npeople: npeople
          })

        omop_id_bins = [bin | Map.get(acc, omop_id, [])]

        Map.put(acc, omop_id, omop_id_bins)
      end)

    for {omop_id, bins} <- map_continuous_distributions do
      omop_concept_dbid = Map.fetch!(omop_ids, omop_id)
      metadata = Map.fetch!(map_metadata, omop_id)
      Map.merge(%{omop_concept_dbid: omop_concept_dbid, bins: bins}, metadata)
    end
  end

  defp import_stats_distributions_lab_values_discrete(discrete_stats_file_path) do
    omop_ids = OMOP.get_map_omop_ids()

    discrete_stats_file_path
    |> File.stream!(:line)
    |> Stream.map(&Jason.decode!/1)
    |> Enum.reduce(%{}, fn row, acc ->
      %{"OMOP_CONCEPT_ID" => omop_id} = row
      rows = [row | Map.get(acc, omop_id, [])]
      Map.put(acc, omop_id, rows)
    end)
    |> Enum.map(fn {omop_id, rows} ->
      omop_concept_dbid = Map.fetch!(omop_ids, omop_id)

      bins =
        Enum.map(rows, fn row ->
          %{
            "MEASUREMENT_VALUE_HARMONIZED" => x,
            "BinCount" => y,
            "NPeople" => npeople
          } = row

          %{x: x, y: y, npeople: npeople}
        end)

      unit = rows |> hd() |> Map.fetch!("MEASUREMENT_UNIT_HARMONIZED")

      %{
        omop_concept_dbid: omop_concept_dbid,
        bins: bins,
        unit: unit
      }
    end)
  end

  defp create_stats_distribution_lab_values(attrs) do
    %DistributionLabValues{}
    |> DistributionLabValues.changeset(attrs)
    |> Repo.insert!()
  end

  def import_stats_distribution_year_of_birth(stats_file_path, bins_definitions_file_path) do
    db_omop_ids = OMOP.get_map_omop_ids()

    %{with_errors: omop_ids_with_errors, without_errors: rows_bins_defs} =
      bins_definitions_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Enum.reduce(%{with_errors: MapSet.new(), without_errors: []}, fn row, acc ->
        %{
          "OMOP_CONCEPT_ID" => omop_id
        } = row

        %{with_errors: with_errors, without_errors: without_errors} = acc

        case {MapSet.member?(with_errors, omop_id), Map.has_key?(db_omop_ids, omop_id)} do
          {true, _} ->
            %{with_errors: with_errors, without_errors: without_errors}

          {false, false} ->
            Logger.warning(
              "Discarding Dist YOB stats for OMOP ID = #{omop_id}: not found in database."
            )

            %{with_errors: MapSet.put(with_errors, omop_id), without_errors: without_errors}

          {false, true} ->
            %{with_errors: with_errors, without_errors: [row | without_errors]}
        end
      end)

    map_bins_definitions =
      rows_bins_defs
      |> Enum.map(fn row ->
        {omop_id, row} = Map.pop!(row, "OMOP_CONCEPT_ID")
        {bin_index, row} = Map.pop!(row, "BinIndex")

        {{omop_id, bin_index}, row}
      end)
      |> Enum.into(%{})

    distributions =
      stats_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Stream.reject(fn %{"OMOP_CONCEPT_ID" => omop_id} ->
        MapSet.member?(omop_ids_with_errors, omop_id)
      end)
      |> Enum.reduce(%{}, fn row, acc ->
        %{
          "OMOP_CONCEPT_ID" => omop_id,
          "BinIndex" => bin_index,
          "NPeople" => npeople,
          "BinCount" => yy
        } = row

        y_formatted = RisteysWeb.Utils.pretty_number(yy)

        bin_metadata = Map.fetch!(map_bins_definitions, {omop_id, bin_index})

        %{
          "BinX1" => x1,
          "BinX2" => x2,
          "BinLabel" => x1x2_formatted,
          "BreakMin" => break_min,
          "BreakMax" => break_max
        } = bin_metadata

        this_bin = %{
          x1: x1,
          x2: x2,
          x1x2_formatted: x1x2_formatted,
          y: yy,
          y_formatted: y_formatted,
          npeople: npeople
        }

        bins = get_in(acc, [omop_id, :bins]) || []
        bins = [this_bin | bins]

        distribution = %{
          bins: bins,
          break_min: break_min,
          break_max: break_max
        }

        Map.put(acc, omop_id, distribution)
      end)

    attrs_list =
      for {omop_id, distribution} <- distributions do
        omop_dbid = Map.fetch!(db_omop_ids, omop_id)

        %{
          omop_concept_dbid: omop_dbid,
          distribution: distribution
        }
      end

    Repo.transaction(fn ->
      Repo.delete_all(DistributionYearOfBirth)

      Enum.each(attrs_list, &create_stats_distribution_year_of_birth/1)
    end)
  end

  defp create_stats_distribution_year_of_birth(attrs) do
    %DistributionYearOfBirth{}
    |> DistributionYearOfBirth.changeset(attrs)
    |> Repo.insert!()
  end

  def import_stats_distribution_age_first_measurement(
        stats_file_path,
        bins_definitions_file_path
      ) do
    db_omop_ids = OMOP.get_map_omop_ids()

    %{with_errors: omop_ids_with_errors, without_errors: rows_bins_defs} =
      bins_definitions_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Enum.reduce(%{with_errors: MapSet.new(), without_errors: []}, fn row, acc ->
        %{"OMOP_CONCEPT_ID" => omop_id} = row

        %{with_errors: with_errors, without_errors: without_errors} = acc

        case {MapSet.member?(with_errors, omop_id), Map.has_key?(db_omop_ids, omop_id)} do
          {true, _} ->
            acc

          {false, false} ->
            Logger.warning(
              "Discarding Dist age at 1st measurement for OMOP ID = #{omop_id}: not found in database."
            )

            %{acc | with_errors: MapSet.put(with_errors, omop_id)}

          {false, true} ->
            %{acc | without_errors: [row | without_errors]}
        end
      end)

    map_bins_definitions =
      rows_bins_defs
      |> Enum.map(fn row ->
        {omop_id, row} = Map.pop!(row, "OMOP_CONCEPT_ID")
        {bin_index, row} = Map.pop!(row, "BinIndex")

        {{omop_id, bin_index}, row}
      end)
      |> Enum.into(%{})

    distributions =
      stats_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Stream.reject(fn %{"OMOP_CONCEPT_ID" => omop_id} ->
        MapSet.member?(omop_ids_with_errors, omop_id)
      end)
      |> Enum.reduce(%{}, fn row, acc ->
        %{
          "OMOP_CONCEPT_ID" => omop_id,
          "BinIndex" => bin_index,
          "NPeople" => npeople,
          "BinCount" => yy
        } = row

        y_formatted = RisteysWeb.Utils.pretty_number(yy)

        bin_metadata = Map.fetch!(map_bins_definitions, {omop_id, bin_index})

        %{
          "BinX1" => x1,
          "BinX2" => x2,
          "BinLabel" => x1x2_formatted,
          "BreakMin" => break_min,
          "BreakMax" => break_max
        } = bin_metadata

        this_bin = %{
          x1: x1,
          x2: x2,
          x1x2_formatted: x1x2_formatted,
          y: yy,
          y_formatted: y_formatted,
          npeople: npeople
        }

        bins = get_in(acc, [omop_id, :bins]) || []
        bins = [this_bin | bins]

        distribution = %{
          bins: bins,
          xmin: break_min,
          xmax: break_max
        }

        Map.put(acc, omop_id, distribution)
      end)

    attrs_list =
      for {omop_id, distribution} <- distributions do
        omop_dbid = Map.fetch!(db_omop_ids, omop_id)

        %{
          omop_concept_dbid: omop_dbid,
          distribution: distribution
        }
      end

    Repo.transaction(fn ->
      Repo.delete_all(DistributionAgeFirstMeasurement)

      Enum.each(attrs_list, &create_stats_distribution_age_first_measurement/1)
    end)
  end

  defp create_stats_distribution_age_first_measurement(attrs) do
    %DistributionAgeFirstMeasurement{}
    |> DistributionAgeFirstMeasurement.changeset(attrs)
    |> Repo.insert!()
  end

  def import_stats_distribution_age_last_measurement(stats_file_path, bins_definitions_file_path) do
    db_omop_ids = OMOP.get_map_omop_ids()

    %{with_errors: omop_ids_with_errors, without_errors: rows_bins_defs} =
      bins_definitions_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Enum.reduce(%{with_errors: MapSet.new(), without_errors: []}, fn row, acc ->
        %{"OMOP_CONCEPT_ID" => omop_id} = row

        case {MapSet.member?(acc.with_errors, omop_id), Map.has_key?(db_omop_ids, omop_id)} do
          {true, _} ->
            acc

          {false, false} ->
            Logger.warning(
              "Discarding Dist age at last measurement for OMOP ID = #{omop_id}: not found in database."
            )

            %{acc | with_errors: MapSet.put(acc.with_errors, omop_id)}

          {false, true} ->
            %{acc | without_errors: [row | acc.without_errors]}
        end
      end)

    map_bins_definitions =
      rows_bins_defs
      |> Enum.map(fn row ->
        {omop_id, row} = Map.pop!(row, "OMOP_CONCEPT_ID")
        {bin_index, row} = Map.pop!(row, "BinIndex")

        {{omop_id, bin_index}, row}
      end)
      |> Enum.into(%{})

    distributions =
      stats_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Stream.reject(fn %{"OMOP_CONCEPT_ID" => omop_id} ->
        MapSet.member?(omop_ids_with_errors, omop_id)
      end)
      |> Enum.reduce(%{}, fn row, acc ->
        %{
          "OMOP_CONCEPT_ID" => omop_id,
          "BinIndex" => bin_index,
          "NPeople" => npeople,
          "BinCount" => yy
        } = row

        y_formatted = RisteysWeb.Utils.pretty_number(yy)

        bin_metadata = Map.fetch!(map_bins_definitions, {omop_id, bin_index})

        %{
          "BinX1" => x1,
          "BinX2" => x2,
          "BinLabel" => x1x2_formatted,
          "BreakMin" => break_min,
          "BreakMax" => break_max
        } = bin_metadata

        this_bin = %{
          x1: x1,
          x2: x2,
          x1x2_formatted: "#{x1x2_formatted} years",
          y: yy,
          y_formatted: y_formatted,
          npeople: npeople
        }

        bins = get_in(acc, [omop_id, :bins]) || []
        bins = [this_bin | bins]

        distribution = %{
          bins: bins,
          xmin: break_min,
          xmax: break_max
        }

        Map.put(acc, omop_id, distribution)
      end)

    attrs_list =
      for {omop_id, distribution} <- distributions do
        omop_dbid = Map.fetch!(db_omop_ids, omop_id)

        %{
          omop_concept_dbid: omop_dbid,
          distribution: distribution
        }
      end

    Repo.transaction(fn ->
      Repo.delete_all(DistributionAgeLastMeasurement)

      Enum.each(attrs_list, &create_stats_distribution_age_last_measurement/1)
    end)
  end

  defp create_stats_distribution_age_last_measurement(attrs) do
    %DistributionAgeLastMeasurement{}
    |> DistributionAgeLastMeasurement.changeset(attrs)
    |> Repo.insert!()
  end

  def import_stats_distribution_age_start_of_registry(stats_file_path, bins_definitions_file_path) do
    db_omop_ids = OMOP.get_map_omop_ids()

    %{with_errors: omop_ids_with_errors, without_errors: rows_bins_defs} =
      bins_definitions_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Enum.reduce(%{with_errors: MapSet.new(), without_errors: []}, fn row, acc ->
        %{"OMOP_CONCEPT_ID" => omop_id} = row

        case {MapSet.member?(acc.with_errors, omop_id), Map.has_key?(db_omop_ids, omop_id)} do
          {true, _} ->
            acc

          {false, false} ->
            Logger.warning(
              "Discarding Dist age at start of registry for OMOP ID = #{omop_id}: not found in database."
            )

            %{acc | with_errors: MapSet.put(acc.with_errors, omop_id)}

          {false, true} ->
            %{acc | without_errors: [row | acc.without_errors]}
        end
      end)

    map_bins_definitions =
      rows_bins_defs
      |> Enum.map(fn row ->
        {omop_id, row} = Map.pop!(row, "OMOP_CONCEPT_ID")
        {bin_index, row} = Map.pop!(row, "BinIndex")

        {{omop_id, bin_index}, row}
      end)
      |> Enum.into(%{})

    distributions =
      stats_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Stream.reject(fn %{"OMOP_CONCEPT_ID" => omop_id} ->
        MapSet.member?(omop_ids_with_errors, omop_id)
      end)
      |> Enum.reduce(%{}, fn row, acc ->
        %{
          "OMOP_CONCEPT_ID" => omop_id,
          "BinIndex" => bin_index,
          "NPeople" => npeople,
          "BinCount" => yy
        } = row

        y_formatted = RisteysWeb.Utils.pretty_number(yy)

        bin_metadata = Map.fetch!(map_bins_definitions, {omop_id, bin_index})

        %{
          "BinX1" => x1,
          "BinX2" => x2,
          "BinLabel" => x1x2_formatted,
          "BreakMin" => break_min,
          "BreakMax" => break_max
        } = bin_metadata

        this_bin = %{
          x1: x1,
          x2: x2,
          x1x2_formatted: "#{x1x2_formatted} years",
          y: yy,
          y_formatted: y_formatted,
          npeople: npeople
        }

        bins = get_in(acc, [omop_id, :bins]) || []
        bins = [this_bin | bins]

        distribution = %{
          bins: bins,
          xmin: break_min,
          xmax: break_max
        }

        Map.put(acc, omop_id, distribution)
      end)

    attrs_list =
      for {omop_id, distribution} <- distributions do
        omop_dbid = Map.fetch!(db_omop_ids, omop_id)

        %{
          omop_concept_dbid: omop_dbid,
          distribution: distribution
        }
      end

    Repo.transaction(fn ->
      Repo.delete_all(DistributionAgeStartOfRegistry)

      Enum.each(attrs_list, &create_stats_distribution_age_start_of_registry/1)
    end)
  end

  defp create_stats_distribution_age_start_of_registry(attrs) do
    %DistributionAgeStartOfRegistry{}
    |> DistributionAgeStartOfRegistry.changeset(attrs)
    |> Repo.insert!()
  end

  def import_stats_distribution_duration_first_to_last_measurement(
        stats_file_path,
        bins_definitions_file_path
      ) do
    db_omop_ids = OMOP.get_map_omop_ids()

    %{with_errors: omop_ids_with_errors, without_errors: rows_bins_defs} =
      bins_definitions_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Enum.reduce(%{with_errors: MapSet.new(), without_errors: []}, fn row, acc ->
        %{"OMOP_CONCEPT_ID" => omop_id} = row

        case {MapSet.member?(acc.with_errors, omop_id), Map.has_key?(db_omop_ids, omop_id)} do
          {true, _} ->
            acc

          {false, false} ->
            Logger.warning(
              "Discarding Dist duration 1st–last measurement for OMOP ID = #{omop_id}: not found in database."
            )

            %{acc | with_errors: MapSet.put(acc.with_errors, omop_id)}

          {false, true} ->
            %{acc | without_errors: [row | acc.without_errors]}
        end
      end)

    map_bins_definitions =
      rows_bins_defs
      |> Enum.map(fn row ->
        {omop_id, row} = Map.pop!(row, "OMOP_CONCEPT_ID")
        {bin_index, row} = Map.pop!(row, "BinIndex")

        {{omop_id, bin_index}, row}
      end)
      |> Enum.into(%{})

    distributions =
      stats_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Stream.reject(fn %{"OMOP_CONCEPT_ID" => omop_id} ->
        MapSet.member?(omop_ids_with_errors, omop_id)
      end)
      |> Enum.reduce(%{}, fn row, acc ->
        %{
          "OMOP_CONCEPT_ID" => omop_id,
          "BinIndex" => bin_index,
          "NPeople" => npeople,
          "BinCount" => yy
        } = row

        y_formatted = RisteysWeb.Utils.pretty_number(yy)

        bin_metadata = Map.fetch!(map_bins_definitions, {omop_id, bin_index})

        %{
          "BinX1" => x1,
          "BinX2" => x2,
          "BinLabel" => x1x2_formatted,
          "BreakMin" => xmin,
          "BreakMax" => xmax
        } = bin_metadata

        this_bin = %{
          x1: x1,
          x2: x2,
          x1x2_formatted: "#{x1x2_formatted} years",
          y: yy,
          y_formatted: y_formatted,
          npeople: npeople
        }

        bins = get_in(acc, [omop_id, :bins]) || []
        bins = [this_bin | bins]

        distribution = %{
          bins: bins,
          xmin: xmin,
          xmax: xmax
        }

        Map.put(acc, omop_id, distribution)
      end)

    attrs_list =
      for {omop_id, distribution} <- distributions do
        omop_dbid = Map.fetch!(db_omop_ids, omop_id)

        %{
          omop_concept_dbid: omop_dbid,
          distribution: distribution
        }
      end

    Repo.transaction(fn ->
      Repo.delete_all(DistributionNYearsFirstToLastMeasurement)

      Enum.each(attrs_list, &create_stats_distribution_first_to_last_measurement/1)
    end)
  end

  defp create_stats_distribution_first_to_last_measurement(attrs) do
    %DistributionNYearsFirstToLastMeasurement{}
    |> DistributionNYearsFirstToLastMeasurement.changeset(attrs)
    |> Repo.insert!()
  end

  def import_stats_distribution_n_measurements_over_years(stats_file_path) do
    omop_ids = OMOP.get_map_omop_ids()

    bins_map =
      stats_file_path
      |> read_stats_rows()
      |> group_bins_by(["OMOP_ID"])
      # Ungroup the single-value group ["OMOP_ID]
      |> Enum.map(fn {[omop_concept_id], rows} -> {omop_concept_id, rows} end)
      |> Enum.map(fn {key, rows} ->
        new_rows =
          for row <- rows do
            %{
              "YearMonth" => range,
              "NRecords" => nrecords,
              "NPeople" => npeople
            } = row

            {nrecords_int, ""} = Integer.parse(nrecords)
            {npeople_int, ""} = Integer.parse(npeople)

            %{
              "range" => range,
              "nrecords" => nrecords_int,
              "npeople" => npeople_int
            }
          end

        {key, new_rows}
      end)

    # TODO(Vincent 2024-06-19)  Use breaks from the pipeline output.
    # Currently these stats don't come with an associated breaks list, because
    # the pipeline just aggregate on OMOP_ID and YearMonth, withouth pre-
    # computing the YearMonth.
    # Ideally the YearMonth breaks list is written as part of the pipeline
    # output and then used here.
    # But for now we don't have it, so I decide to generate it on the fly here.
    year_month_list =
      for year <- 2014..2022, month <- 1..12 do
        month_str =
          month
          |> to_string()
          |> String.pad_leading(2, "0")

        "#{year}-#{month_str}"
      end

    attrs_list =
      for {omop_concept_id, bins} <- bins_map do
        %{
          omop_concept_dbid: Map.fetch!(omop_ids, omop_concept_id),
          distribution: %{"bins" => bins, "breaks" => year_month_list}
        }
      end

    {:ok, :ok} =
      Repo.transaction(fn ->
        Repo.delete_all(DistributionNMeasurementsOverYears)

        Enum.each(attrs_list, &create_stats_distribution_n_measurements_over_years/1)
      end)
  end

  defp create_stats_distribution_n_measurements_over_years(attrs) do
    %DistributionNMeasurementsOverYears{}
    |> DistributionNMeasurementsOverYears.changeset(attrs)
    |> Repo.insert!()
  end

  def import_stats_distribution_n_measurements_per_person(stats_file_path) do
    omop_ids = OMOP.get_map_omop_ids()

    bins_map =
      stats_file_path
      |> read_stats_rows()
      |> group_bins_by(["OMOP_ID"])
      # Ungroup the single-value group ["OMOP_ID]
      |> Enum.map(fn {[omop_concept_id], rows} -> {omop_concept_id, rows} end)
      |> Enum.map(fn {key, rows} ->
        new_rows =
          for row <- rows do
            %{
              "Bin" => nmeasurements,
              "NPeople" => npeople
            } = row

            {nmeasurements_int, ""} = Integer.parse(nmeasurements)
            {npeople_int, ""} = Integer.parse(npeople)

            %{
              "nmeasurements" => nmeasurements_int,
              "npeople" => npeople_int
            }
          end

        {key, new_rows}
      end)

    # TODO(Vincent 2024-06-20)  Reconstructing missing bins here, but ideally
    # it should be done from an output file of the pipeline.
    breaks_indexed =
      for {omop_id, bins} <- bins_map, into: %{} do
        max_measurements =
          bins
          |> Enum.map(fn %{"nmeasurements" => nn} -> nn end)
          |> Enum.max()

        breaks = Range.to_list(1..max_measurements)

        {omop_id, breaks}
      end

    attrs_list =
      for {omop_concept_id, bins} <- bins_map do
        %{
          omop_concept_dbid: Map.fetch!(omop_ids, omop_concept_id),
          distribution: %{
            "bins" => bins,
            "breaks" => Map.fetch!(breaks_indexed, omop_concept_id)
          }
        }
      end

    {:ok, :ok} =
      Repo.transaction(fn ->
        Repo.delete_all(DistributionNMeasurementsPerPerson)

        Enum.each(attrs_list, &create_stats_distribution_n_measurements_per_person/1)
      end)
  end

  defp create_stats_distribution_n_measurements_per_person(attrs) do
    %DistributionNMeasurementsPerPerson{}
    |> DistributionNMeasurementsPerPerson.changeset(attrs)
    |> Repo.insert!()
  end

  def import_stats_distribution_value_range_per_person(stats_file_path, breaks_file_path) do
    stats_columns = %{
      "Bin" => %{
        to: "range",
        parser: &Function.identity/1
      },
      "NPeople" => %{
        to: "npeople",
        parser: fn npeople ->
          {npeople_int, ""} = Integer.parse(npeople)
          npeople_int
        end
      }
    }

    attrs_list =
      load_distribution_as_attrs_list(
        stats_file_path,
        stats_columns,
        breaks_file_path,
        &Function.identity/1
      )

    {:ok, :ok} =
      Repo.transaction(fn ->
        Repo.delete_all(DistributionValueRangePerPerson)

        Enum.each(attrs_list, &create_stats_distribution_value_range_per_person/1)
      end)
  end

  defp create_stats_distribution_value_range_per_person(attrs) do
    %DistributionValueRangePerPerson{}
    |> DistributionValueRangePerPerson.changeset(attrs)
    |> Repo.insert!()
  end

  def load_distribution_as_attrs_list(
        stats_file_path,
        columns_spec,
        breaks_file_path,
        break_parser
      ) do
    omop_ids = OMOP.get_map_omop_ids()

    bins_map =
      stats_file_path
      |> read_stats_rows()
      |> group_bins_by(["OMOP_ID"])
      # Ungroup the single-value group ["OMOP_ID]
      |> Enum.map(fn {[omop_concept_id], rows} -> {omop_concept_id, rows} end)
      |> Enum.map(fn {key, rows} ->
        new_rows =
          for row <- rows do
            for column <- columns_spec, into: %{} do
              {column_source, %{to: column_internal, parser: column_parser}} = column

              %{^column_source => value} = row

              parsed_value = column_parser.(value)

              {column_internal, parsed_value}
            end
          end

        {key, new_rows}
      end)

    breaks_map =
      breaks_file_path
      |> File.stream!()
      |> Stream.map(&Jason.decode!/1)
      |> Enum.reduce(%{}, fn row, acc ->
        %{
          "omop_id" => omop_concept_id,
          "breaks" => breaks_list,
          "left_closed" => true
        } = row

        breaks_list_parsed = Enum.map(breaks_list, break_parser)

        Map.put(acc, omop_concept_id, breaks_list_parsed)
      end)

    for {omop_concept_id, bins} <- bins_map do
      breaks = Map.get(breaks_map, omop_concept_id, [])

      %{
        omop_concept_dbid: Map.fetch!(omop_ids, omop_concept_id),
        distribution: %{"bins" => bins, "breaks" => breaks}
      }
    end
  end

  # Takes a bin stats file path and returns the rows for which we have OMOP ID
  # already in our database.
  defp read_stats_rows(stats_file_path) do
    omop_ids = OMOP.get_map_omop_ids()

    stats_file_path
    |> File.stream!()
    |> CSV.decode!(headers: true)
    |> Stream.reject(fn %{"OMOP_ID" => omop_concept_id} -> omop_concept_id == "NA" end)
    # Discard rows that are related to an OMOP Concept ID we don't have in the DB.
    # This assumes that the OMOP concept IDs have been imported already.
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
  end

  defp group_bins_by(bin_rows, group_by_columns) do
    bin_rows
    |> Enum.reduce(%{}, fn row, acc ->
      key = Enum.map(group_by_columns, &Map.fetch!(row, &1))

      Map.update(acc, key, [row], fn existing_rows ->
        [row | existing_rows]
      end)
    end)
  end

  @doc """
  Helper changeset validator to validate N people is green (N=0, or N>= 5).
  Returns a list of changeset errors.
  """
  def validate_npeople_green(field, distribution, access_to_bin, key_npeople) do
    distribution
    |> get_in(access_to_bin)
    |> Enum.map(fn bin ->
      case Map.fetch(bin, key_npeople) do
        :error ->
          {field, "Bin is missing the key #{key_npeople}, bin=#{inspect(bin)}"}

        {:ok, npeople} when is_integer(npeople) and npeople > 0 and npeople < 5 ->
          {field,
           "Bin has wrong value for #{key_npeople}, expected an integer >= 5 or 0, instead got: #{inspect(npeople)} in bin=#{inspect(bin)}"}

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp rebuild_distribution(distribution, rename_fields, default) do
    %{
      "bins" => bins,
      "breaks" => breaks
    } = distribution

    # Derive break interval
    # TODO(Vincent 2024-05-27)  Use pre-computed break interval value from the
    # data when that's implemented and available in DB.
    breaks = Enum.sort(breaks, :asc)
    [break1, break2] = Enum.take(breaks, 2)
    break_interval = break2 - break1

    new_bins =
      bins
      # Rename bin fields/keys
      |> Enum.map(fn bin ->
        for {old_name, new_name} <- rename_fields, reduce: bin do
          acc ->
            {value, acc} = Map.pop!(acc, old_name)
            Map.put(acc, new_name, value)
        end
      end)
      |> reconstruct_bins(breaks, break_interval, default)

    %{distribution | "bins" => new_bins}
  end

  defp reconstruct_bins(bins, breaks, break_interval, default) do
    bins =
      Enum.map(bins, fn bin ->
        [range_left_str, range_right_str] = extract_range_values(bin.range)

        {range_left, range_left_finite} =
          case range_left_str do
            "-inf" ->
              left = :minus_infinity
              right = RisteysWeb.Utils.parse_number(range_right_str)
              left_finite = right - break_interval
              {left, left_finite}

            _ ->
              left = RisteysWeb.Utils.parse_number(range_left_str)
              {left, left}
          end

        {range_right, range_right_finite} =
          case range_right_str do
            "inf" ->
              right = :plus_infinity
              left = RisteysWeb.Utils.parse_number(range_left_str)
              right_finite = left + break_interval
              {right, right_finite}

            _ ->
              right = RisteysWeb.Utils.parse_number(range_right_str)
              {right, right}
          end

        Map.merge(
          bin,
          %{
            range_left: range_left,
            range_left_finite: range_left_finite,
            range_right: range_right,
            range_right_finite: range_right_finite
          }
        )
      end)
      |> Enum.sort_by(fn bin -> bin.range_left end, :asc)

    gaps =
      for [bin_left, bin_right] <- Enum.chunk_every(bins, 2, 1, :discard), reduce: [] do
        acc ->
          if bin_left.range_right_finite != bin_right.range_left_finite do
            [%{left: bin_left.range_right_finite, right: bin_right.range_left_finite} | acc]
          else
            acc
          end
      end

    first_break = Enum.fetch!(breaks, 0)
    last_break = Enum.fetch!(breaks, -1)
    first_bin = Enum.fetch!(bins, 0)
    last_bin = Enum.fetch!(bins, -1)

    gaps =
      if first_bin.range_left == :minus_infinity do
        gaps
      else
        [%{left: first_break, right: first_bin.range_left_finite} | gaps]
      end

    gaps =
      if last_bin.range_right == :plus_infinity do
        gaps
      else
        last_gap = %{left: last_bin.range_right_finite, right: :plus_infinity}
        Enum.concat([gaps, [last_gap]])
      end

    new_bins =
      gaps
      |> Enum.map(&fill_gap(&1, break_interval, last_break, default))
      |> Enum.concat()

    [bins, new_bins]
    |> Enum.concat()
    |> Enum.sort_by(fn %{range_left_finite: range_left_finite} -> range_left_finite end, :asc)
  end

  defp fill_gap(gap, break_interval, last_break, default) do
    gap_right_finite =
      if gap.right == :plus_infinity do
        last_break + break_interval
      else
        gap.right
      end

    n_missing_bins = round((gap_right_finite - gap.left) / break_interval)

    1..n_missing_bins//1
    |> Enum.map(fn ii ->
      right = gap.left + ii * break_interval
      left = right - break_interval

      range_right =
        if ii == n_missing_bins and gap.right == :plus_infinity do
          :plus_infinity
        else
          right
        end

      Map.merge(
        default,
        %{
          range_left: left,
          range_left_finite: left,
          range_right: range_right,
          range_right_finite: right
        }
      )
    end)
  end

  defp rebuild_year_month_distribution(distribution) do
    %{
      "bins" => bins,
      "breaks" => breaks
    } = distribution

    bins_indexed =
      for bin <- bins, into: %{} do
        %{"range" => range} = bin
        {range, bin}
      end

    for break <- breaks do
      case Map.fetch(bins_indexed, break) do
        {:ok, bin} ->
          %{
            "range" => xx,
            "nrecords" => yy
          } = bin

          %{year_month: xx, nrecords: yy}

        :error ->
          %{year_month: break, nrecords: 0}
      end
    end
  end

  defp rebuild_n_measurements_per_person_distribution(distribution) do
    %{
      "bins" => bins,
      "breaks" => breaks
    } = distribution

    bins_indexed =
      for bin <- bins, into: %{} do
        %{"nmeasurements" => n_measurements} = bin
        {n_measurements, bin}
      end

    for break <- breaks do
      %{"npeople" => n_people} = Map.get(bins_indexed, break, %{"npeople" => 0})
      %{n_measurements: break, npeople: n_people}
    end
  end

  defp extract_range_values(range) do
    [x1, x2] = String.split(range, ", ")
    x1 = String.slice(x1, 1..-1//1)
    x2 = String.slice(x2, 0..-2//1)

    [x1, x2]
  end
end
