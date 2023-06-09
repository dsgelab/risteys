defmodule Risteys.Repo.Migrations.DropMortalityStats do
  use Ecto.Migration

  def up do
    drop table(:mortality_stats)
  end

  def down do
    create table(:mortality_stats) do
      add :lagged_hr_cut_year, :integer, null: false  # "0" indicates no lagged HR
      add :hr, :float, null: false
      add :hr_ci_min, :float, null: false
      add :hr_ci_max, :float, null: false
      add :pvalue, :float, null: false
      add :n_individuals, :integer, null: false
      add :absolute_risk, :float, null: false
      add :fg_endpoint_id, references(:fg_endpoint_definitions, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:mortality_stats, [:fg_endpoint_id, :lagged_hr_cut_year], name: :fg_endpoint_hrlag)
  end
end
