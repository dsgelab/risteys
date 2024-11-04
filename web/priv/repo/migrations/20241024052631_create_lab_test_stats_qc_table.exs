defmodule Risteys.Repo.Migrations.CreateLabTestStatsQcTable do
  use Ecto.Migration

  def change do
    create table(:lab_test_stats_qc_table) do
      add :test_name, :string, null: false
      add :measurement_unit, :string, null: true
      add :measurement_unit_harmonized, :string, null: true
      add :nrecords, :integer, null: false
      add :npeople, :integer, null: false
      add :percent_missing_measurement_value, :float, null: false
      add :test_outcome_counts, {:array, :map}, null: true
      add :distribution_measurement_values, :map, null: true
      add :omop_concept_dbid, references(:omop_concepts, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:lab_test_stats_qc_table, [:omop_concept_dbid, :test_name, :measurement_unit])
  end
end
