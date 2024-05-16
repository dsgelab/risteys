defmodule Risteys.Repo.Migrations.CreateLabTestStatsMedianNDaysFirstToLastMeasurement do
  use Ecto.Migration

  def change do
    create table(:lab_test_stats_median_ndays_first_to_last_measurement) do
      add :median_ndays_first_to_last_measurement, :float, null: false
      add :npeople, :integer, null: false
      add :omop_concept_dbid, references(:omop_concepts, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:lab_test_stats_median_ndays_first_to_last_measurement, [:omop_concept_dbid])
  end
end
