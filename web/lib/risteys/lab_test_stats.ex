defmodule Risteys.LabTestStats do
  @moduledoc """
  The LabTestStats context.
  """

  import Ecto.Query, warn: false
  alias Risteys.Repo
  alias Risteys.OMOP
  alias Risteys.LabTestStats.NPeople
  alias Risteys.LabTestStats.MedianNMeasurements

  require Logger

  @doc """
  Takes a tree of OMOP lab tests and attach stats to it.
  """
  def merge_stats(lab_tests_tree) do
    empty_stats = %{
      npeople_male: nil,
      npeople_female: nil,
      npeople_total: nil,
      sex_female_percent: nil,
      median_n_measurements: nil
    }

    npeople_stats = get_stats_npeople()
    median_n_measurements_stats = get_stats_median_n_measurements()

    for %{lab_tests: lab_tests} = rec <- lab_tests_tree do
      with_stats =
        for lab_test <- lab_tests do
          lab_test
          |> Map.merge(Map.get(npeople_stats, lab_test.lab_test_concept_id, empty_stats))
          |> Map.merge(
            Map.get(median_n_measurements_stats, lab_test.lab_test_concept_id, empty_stats)
          )
        end
        |> Enum.sort_by(fn stats -> stats.npeople_total end, :desc)

      %{rec | lab_tests: with_stats}
    end
  end

  def get_overall_stats() do
    %{
      npeople: get_overall_stats_npeople(),
      median_n_measurements: get_overall_stats_median_n_measurements()
    }
  end

  defp get_overall_stats_npeople() do
    query_count_by_omopid =
      from npeople_stats in NPeople,
        left_join: omop_concept in OMOP.Concept,
        on: npeople_stats.omop_concept_dbid == omop_concept.id,
        group_by: omop_concept.concept_id,
        select: %{npeople: sum(npeople_stats.count)}

    Repo.one(
      from counts in subquery(query_count_by_omopid),
        select: max(counts.npeople)
    )
  end

  defp get_overall_stats_median_n_measurements() do
    Repo.one(
      from stats in MedianNMeasurements,
        select: max(stats.median_n_measurements)
    )
  end

  @doc """
  Reset all the lab test stats for N People using data from file.
  """
  def import_stats_npeople(file_path) do
    omop_ids =
      Repo.all(
        from omop_concept in OMOP.Concept,
          select: {omop_concept.concept_id, omop_concept.id}
      )
      |> Enum.into(%{})

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
      |> Enum.map(fn row ->
        %{
          "OMOP_ID" => omop_concept_id,
          "Sex" => sex,
          "NPeople" => count
        } = row

        omop_concept_dbid = Map.fetch!(omop_ids, omop_concept_id)

        %{
          omop_concept_dbid: omop_concept_dbid,
          sex: sex,
          count: count
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
      from stat in NPeople,
        left_join: omop_concept in OMOP.Concept,
        on: stat.omop_concept_dbid == omop_concept.id,
        select: %{omop_concept_id: omop_concept.concept_id, sex: stat.sex, count: stat.count}
    )

    # Make sure we have both :npeople_male and :npeople_female set
    |> Enum.reduce(%{}, fn rec, acc ->
      default_stats = %{
        npeople_male: nil,
        npeople_female: nil
      }

      lab_test_stats = Map.get(acc, rec.omop_concept_id, default_stats)

      lab_test_stats =
        case rec.sex do
          "male" ->
            %{lab_test_stats | npeople_male: rec.count}

          "female" ->
            %{lab_test_stats | npeople_female: rec.count}
        end

      Map.put(acc, rec.omop_concept_id, lab_test_stats)
    end)
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

  @doc """
  Reset all the stats for median N measurements using data from file.
  """
  def import_stats_median_n_measurements(file_path) do
    omop_ids =
      Repo.all(
        from lab_test in OMOP.Concept,
          select: {lab_test.concept_id, lab_test.id}
      )
      |> Enum.into(%{})

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
end
