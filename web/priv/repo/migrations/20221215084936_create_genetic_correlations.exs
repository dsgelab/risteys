defmodule Risteys.Repo.Migrations.CreateGeneticCorrelations do
  use Ecto.Migration

  def change do
    create table(:genetic_correlations) do
      add :fg_endpoint_a_id, references(:fg_endpoint_definitions, on_delete: :delete_all), null: false
      add :fg_endpoint_b_id, references(:fg_endpoint_definitions, on_delete: :delete_all), null: false
      add :rg, :float, null: false
      add :se, :float, null: false
      add :pvalue, :float, null: false

      timestamps()
    end

    create unique_index(:genetic_correlations, [:fg_endpoint_a_id, :fg_endpoint_b_id], name: :gen_corr_fg_endpoint_a_b)
  end
end
