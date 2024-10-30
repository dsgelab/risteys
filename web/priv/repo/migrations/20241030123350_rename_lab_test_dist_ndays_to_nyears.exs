defmodule Risteys.Repo.Migrations.RenameLabTestDistNdaysToNyears do
  use Ecto.Migration

  def change do
    rename(
      index(:lab_test_stats_distribution_ndays_first_to_last_measurement, [:omop_concept_dbid]),
      to: "lab_test_stats_distribution_nyears_first_to_last_measurement_omop_concept_dbid_index"
    )

    rename table(:lab_test_stats_distribution_ndays_first_to_last_measurement),
      to: table(:lab_test_stats_distribution_nyears_first_to_last_measurement)
  end
end
