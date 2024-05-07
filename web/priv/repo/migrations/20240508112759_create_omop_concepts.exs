defmodule Risteys.Repo.Migrations.CreateOMOPConcepts do
  use Ecto.Migration

  def change do
    create table(:omop_concepts) do
      add :concept_id, :string, null: false
      add :concept_name, :string, null: false

      timestamps()
    end

    create unique_index(:omop_concepts, [:concept_id], name: :uidx_omop_concepts)
  end
end
