defmodule Risteys.Repo.Migrations.RenameLabTestStatsNdaysToYears do
  use Ecto.Migration

  def change do
    rename table(:lab_test_stats_median_ndays_first_to_last_measurement), :median_ndays_first_to_last_measurement, to: :median_years_first_to_last_measurement
    rename(index(:lab_test_stats_median_ndays_first_to_last_measurement, [:omop_concept_dbid]), to: "lab_test_stats_median_years_first_to_last_measurement_omop_concept_dbid_index")

    rename table(:lab_test_stats_median_ndays_first_to_last_measurement), to: table(:lab_test_stats_median_years_first_to_last_measurement)
  end
end
