defmodule Risteys.Repo.Migrations.CreatePhenocodesIcd9s do
  use Ecto.Migration

  def change do
    create table(:phenocodes_icd9s) do
      add :registry, :string, null: false
      add :phenocode_id, references(:phenocodes, on_delete: :nothing), null: false
      add :icd9_id, references(:icd9s, on_delete: :nothing), null: false

      timestamps()
    end

    create unique_index(:phenocodes_icd9s, [:registry, :phenocode_id, :icd9_id], name: :phenocode_icd9_registry)
  end
end
