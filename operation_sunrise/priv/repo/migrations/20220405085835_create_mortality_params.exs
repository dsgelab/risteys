defmodule Risteys.Repo.Migrations.CreateMortalityParams do
  use Ecto.Migration

  def change do
    create table(:mortality_params) do
      add :fg_endpoint_id, references(:fg_endpoint_definitions, on_delete: :delete_all), null: false
      add :covariate, :string, null: false
      add :coef, :float, null: false
      add :ci95_lower, :float, null: false
      add :ci95_upper, :float, null: false
      add :p_value, :float, null: false
      add :mean, :float, null: false

      timestamps()
    end

    create unique_index(:mortality_params, [:fg_endpoint_id, :covariate], name: :covariate_fg_endpoint_id)
  end
end
