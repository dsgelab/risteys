defmodule Risteys.Repo.Migrations.CreateMortalityBaseline do
  use Ecto.Migration

  def change do
    create table(:mortality_baseline) do
      add :fg_endpoint_id, references(:fg_endpoint_definitions, on_delete: :delete_all), null: false
      add :age, :integer, null: false
      add :baseline_cumulative_hazard, :float, null: false

      timestamps()
    end

    create unique_index(:mortality_baseline, [:fg_endpoint_id, :age], name: :age_fg_endpoint_id)
  end
end
