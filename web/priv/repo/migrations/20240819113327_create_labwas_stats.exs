defmodule Risteys.Repo.Migrations.CreateLabwasStats do
  use Ecto.Migration

  def change do
    create table(:labwas_stats) do
      add :fg_endpoint_id, references(:fg_endpoint_definitions, on_delete: :delete_all)
      add :omop_concept_id, :string, null: false
      add :omop_concept_name, :string, null: true
      add :fg_endpoint_n_cases, :integer, null: false
      add :fg_endpoint_n_controls, :integer, null: false
      add :with_measurement_n_cases, :integer, null: false
      add :with_measurement_n_controls, :integer, null: false
      add :with_measurement_odds_ratio, :float, null: false
      add :with_measurement_mlogp, :float, null: false
      add :mean_n_measurements_cases, :float, null: false
      add :mean_n_measurements_controls, :float, null: false
      add :mean_value_n_cases, :integer, null: true
      add :mean_value_n_controls, :integer, null: true
      add :mean_value_unit, :string, null: true
      add :mean_value_cases, :float, null: true
      add :mean_value_controls, :float, null: true
      add :mean_value_mlogp, :float, null: true

      timestamps()
    end

    create unique_index(:labwas_stats, [:fg_endpoint_id, :omop_concept_id])
  end
end
