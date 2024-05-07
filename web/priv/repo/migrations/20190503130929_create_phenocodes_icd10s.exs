defmodule Risteys.Repo.Migrations.CreatePhenocodesIcd10s do
  use Ecto.Migration

  def change do
    create table(:phenocodes_icd10s) do
      add :registry, :string, null: false
      add :phenocode_id, references(:phenocodes, on_delete: :nothing), null: false
      add :icd10_id, references(:icd10s, on_delete: :nothing), null: false

      timestamps()
    end

    create unique_index(:phenocodes_icd10s, [:registry, :phenocode_id, :icd10_id], name: :phenocode_icd10_registry)
  end
end
