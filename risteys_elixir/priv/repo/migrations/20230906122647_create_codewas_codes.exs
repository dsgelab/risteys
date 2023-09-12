defmodule Risteys.Repo.Migrations.CreateCodewasCodes do
  use Ecto.Migration

  def change do
    create table(:codewas_codes) do
      add :code, :string, null: false
      add :vocabulary, :string, null: false
      add :description, :string, null: false
      add :odds_ratio, :float, null: false
      add :nlog10p, :float, null: false
      add :n_matched_cases, :integer
      add :n_matched_controls, :integer
      add :fg_endpoint_id, references(:fg_endpoint_definitions, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:codewas_codes, [:fg_endpoint_id, :code, :vocabulary])
  end
end
