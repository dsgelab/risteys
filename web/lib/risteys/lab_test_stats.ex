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
  alias Risteys.LabTestStats.DistributionYearOfBirth
  alias Risteys.LabTestStats.DistributionAgeFirstMeasurement
  alias Risteys.LabTestStats.DistributionAgeLastMeasurement
  alias Risteys.LabTestStats.DistributionAgeStartOfRegistry
  alias Risteys.LabTestStats.DistributionNDaysFirstToLastMeasurement
  alias Risteys.LabTestStats.DistributionNMeasurementsOverYears

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
    stats =
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

          # Distributions of lab values
          full_join: distribution_lab_values in DistributionsLabValues,
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
            distribution_ndays_first_to_last_measurement in DistributionNDaysFirstToLastMeasurement,
          on: lab_test.id == distribution_ndays_first_to_last_measurement.omop_concept_dbid,

          # Distribution N measurements over the years
          full_join: distribution_n_measurements_over_years in DistributionNMeasurementsOverYears,
          on: lab_test.id == distribution_n_measurements_over_years.omop_concept_dbid,
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
            distributions_lab_values: distribution_lab_values.distributions,
            distribution_year_of_birth: distribution_year_of_birth.distribution,
            distribution_age_first_measurement: distribution_age_first_measurement.distribution,
            distribution_age_last_measurement: distribution_age_last_measurement.distribution,
            distribution_age_start_of_registry: distribution_age_start_of_registry.distribution,
            distribution_ndays_first_to_last_measurement:
              distribution_ndays_first_to_last_measurement.distribution,
            distribution_n_measurements_over_years:
              distribution_n_measurements_over_years.distribution
          }
      )

    stats =
      Map.put(
        stats,
        :sex_female_percent,
        (100 * stats.npeople_female / stats.npeople_both_sex)
        |> RisteysWeb.Utils.pretty_number()
      )

    distributions_lab_values =
      stats.distributions_lab_values
      |> sort_distributions_lab_values()
      |> Enum.map(fn dist ->
        # Only rebuild the distribution when its values are in a continuous scale
        %{"measurement_unit" => measurement_unit} = dist

        if measurement_unit not in ["binary", "titre"] do
          rebuild_distribution(dist, %{"range" => :range, "nrecords" => :nrecords}, %{nrecords: 0})
        else
          dist
        end
      end)

    distribution_year_of_birth =
      stats.distribution_year_of_birth
      |> rebuild_distribution(%{"range" => :range, "npeople" => :npeople}, %{npeople: 0})

    distribution_age_first_measurement =
      stats.distribution_age_first_measurement
      |> rebuild_distribution(%{"range" => :range, "npeople" => :npeople}, %{npeople: 0})

    distribution_age_last_measurement =
      stats.distribution_age_last_measurement
      |> rebuild_distribution(%{"range" => :range, "npeople" => :npeople}, %{npeople: 0})

    distribution_age_start_of_registry =
      stats.distribution_age_start_of_registry
      |> rebuild_distribution(%{"range" => :range, "npeople" => :npeople}, %{npeople: 0})

    distribution_ndays_first_to_last_measurement =
      stats.distribution_ndays_first_to_last_measurement
      |> rebuild_distribution(%{"range" => :range, "npeople" => :npeople}, %{npeople: 0})

    distribution_n_measurements_over_years =
      stats.distribution_n_measurements_over_years
      |> rebuild_year_month_distribution()

    %{
      stats
      | distributions_lab_values: distributions_lab_values,
        distribution_year_of_birth: distribution_year_of_birth,
        distribution_age_first_measurement: distribution_age_first_measurement,
        distribution_age_last_measurement: distribution_age_last_measurement,
        distribution_age_start_of_registry: distribution_age_start_of_registry,
        distribution_ndays_first_to_last_measurement:
          distribution_ndays_first_to_last_measurement,
        distribution_n_measurements_over_years: distribution_n_measurements_over_years
    }
  end

  defp sort_distributions_lab_values(distribution) do
    Enum.sort_by(
      distribution,
      fn dist ->
        for bin <- dist["bins"], reduce: 0 do
          acc -> acc + bin["nrecords"]
        end
      end,
      :desc
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
      |> read_stats_rows()
      |> group_bins_by(["OMOP_ID", "LAB_UNIT"])
      # Minimal string parsing
      |> Enum.map(fn {key, rows} ->
        new_rows =
          for row <- rows do
            %{
              "Bin" => bin_range,
              "NPeople" => npeople,
              "NRecords" => nrecords
            } = row

            {npeople_int, ""} = Integer.parse(npeople)
            {nrecords_int, ""} = Integer.parse(nrecords)

            %{
              "range" => bin_range,
              "npeople" => npeople_int,
              "nrecords" => nrecords_int
            }
          end

        {key, new_rows}
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

        Map.put(acc, [omop_id, measurement_unit], breaks)
      end)

    # Merging bins and breaks.
    # If some bins don't have associated breaks, then we put an empty break
    # list, because we still want to keep the bins.
    # If some breaks don't have associated bins, then they are silently
    # discarded.
    distributions_map =
      Enum.reduce(bins_map, %{}, fn {[omop_concept_id, measurement_unit] = key, dist_bins}, acc ->
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
        [omop_concept_id, measurement_unit] = key
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

    {:ok, :ok} =
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

  def import_stats_distribution_year_of_birth(stats_file_path, breaks_file_path) do
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
        fn year ->
          {year_int, ""} = Integer.parse(year)
          year_int
        end
      )

    {:ok, :ok} =
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

  def import_stats_distribution_age_first_measurement(stats_file_path, breaks_file_path) do
    stats_columns = %{
      "BinAgeAtFirstMeasurement_years" => %{
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
        fn age ->
          {age_int, ""} = Integer.parse(age)
          age_int
        end
      )

    {:ok, :ok} =
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

  def import_stats_distribution_age_last_measurement(stats_file_path, breaks_file_path) do
    stats_columns = %{
      "BinAgeAtLastMeasurement_years" => %{
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
        fn age ->
          {age_int, ""} = Integer.parse(age)
          age_int
        end
      )

    {:ok, :ok} =
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

  def import_stats_distribution_age_start_of_registry(stats_file_path, breaks_file_path) do
    stats_columns = %{
      "BinAgeAtStudyStart_years" => %{
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
        fn age ->
          {age_int, ""} = Integer.parse(age)
          age_int
        end
      )

    {:ok, :ok} =
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

  def import_stats_distribution_ndays_first_to_last_measurement(
        stats_file_path,
        breaks_file_path
      ) do
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
        Repo.delete_all(DistributionNDaysFirstToLastMeasurement)

        Enum.each(attrs_list, &create_stats_distribution_ndays_first_to_last_measurement/1)
      end)
  end

  defp create_stats_distribution_ndays_first_to_last_measurement(attrs) do
    %DistributionNDaysFirstToLastMeasurement{}
    |> DistributionNDaysFirstToLastMeasurement.changeset(attrs)
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

  defp extract_range_values(range) do
    [x1, x2] = String.split(range, ", ")
    x1 = String.slice(x1, 1..-1//1)
    x2 = String.slice(x2, 0..-2//1)

    [x1, x2]
  end
end
