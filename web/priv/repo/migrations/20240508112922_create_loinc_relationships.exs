defmodule Risteys.Repo.Migrations.CreateLOINCRelationships do
  use Ecto.Migration

  def change do
    create table(:omop_loinc_relationships) do
      add :lab_test_id, references(:omop_concepts, on_delete: :delete_all)
      add :loinc_component_id, references(:omop_concepts, on_delete: :delete_all)

      timestamps()
    end

    create index(:omop_loinc_relationships, [:lab_test_id])
    create index(:omop_loinc_relationships, [:loinc_component_id])
    create unique_index(:omop_loinc_relationships, [:lab_test_id, :loinc_component_id], name: :uidx_omop_loinc_relationships)
  end
end
