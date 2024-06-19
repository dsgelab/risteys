defmodule Risteys.Repo.Migrations.CreateLabTestStatsDistributionNMeasurementsOverYears do
  use Ecto.Migration

  def change do
    create table(:lab_test_stats_distribution_n_measurements_over_years) do
      add :omop_concept_dbid, references(:omop_concepts, on_delete: :delete_all), null: false
      add :distribution, :map, null: false

      timestamps()
    end

    create unique_index(:lab_test_stats_distribution_n_measurements_over_years, [:omop_concept_dbid])
  end
end
