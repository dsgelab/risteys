defmodule Risteys.Repo.Migrations.CreateLabTestStatsMedianNMeasurements do
  use Ecto.Migration

  def change do
    create table(:lab_test_stats_median_n_measurements) do
      add :median_n_measurements, :float, null: false
      add :npeople, :integer, null: false
      add :omop_concept_dbid, references(:omop_concepts, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:lab_test_stats_median_n_measurements, [:omop_concept_dbid])
  end
end
