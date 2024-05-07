defmodule Risteys.Repo.Migrations.CreateMortalityStats do
  use Ecto.Migration

  def change do
    create table(:mortality_stats) do
      add :lagged_hr_cut_year, :integer, null: false  # "0" indicates no lagged HR
      add :hr, :float, null: false
      add :hr_ci_min, :float, null: false
      add :hr_ci_max, :float, null: false
      add :pvalue, :float, null: false
      add :n_individuals, :integer, null: false
      add :absolute_risk, :float, null: false
      add :phenocode_id, references(:phenocodes, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:mortality_stats, [:phenocode_id, :lagged_hr_cut_year], name: :phenocode_hrlag)
  end
end
