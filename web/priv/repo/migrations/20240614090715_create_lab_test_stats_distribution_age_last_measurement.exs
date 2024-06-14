defmodule Risteys.Repo.Migrations.CreateLabTestStatsDistributionAgeLastMeasurement do
  use Ecto.Migration

  def change do
    create table(:lab_test_stats_distribution_age_last_measurement) do
      add :omop_concept_dbid, references(:omop_concepts, on_delete: :delete_all), null: false
      add :distribution, :map, null: false

      timestamps()
    end

    create unique_index(:lab_test_stats_distribution_age_last_measurement, [:omop_concept_dbid])
  end
end
