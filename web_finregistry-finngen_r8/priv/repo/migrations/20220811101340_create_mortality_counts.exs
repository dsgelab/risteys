defmodule Risteys.Repo.Migrations.CreateMortalityCounts do
  use Ecto.Migration

  def change do
    create table(:mortality_counts) do
      add :fg_endpoint_id, references(:fg_endpoint_definitions, on_delete: :delete_all), null: false
      add :exposed, :integer, null: false
      add :exposed_cases, :integer, null: false
      add :sex, :string, null: false

      timestamps()
    end

    create unique_index(:mortality_counts, [:fg_endpoint_id, :sex], name: :fg_endpoint_id_sex)
  end
end
