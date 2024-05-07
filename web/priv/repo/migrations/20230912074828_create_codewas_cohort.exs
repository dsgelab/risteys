defmodule Risteys.Repo.Migrations.CreateCodewasCohort do
  use Ecto.Migration

  def change do
    create table(:codewas_cohort) do
      add :n_matched_cases, :integer, null: false
      add :n_matched_controls, :integer, null: false
      add :fg_endpoint_id, references(:fg_endpoint_definitions, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:codewas_cohort, [:fg_endpoint_id])
  end
end
