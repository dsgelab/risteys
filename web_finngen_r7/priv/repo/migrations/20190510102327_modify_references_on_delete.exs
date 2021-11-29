defmodule Risteys.Repo.Migrations.ModifyReferencesOnDelete do
  use Ecto.Migration

  def change do
    alter table(:stats_sex) do
      modify :phenocode_id, references(:phenocodes, on_delete: :delete_all), from: references(:phenocodes, on_delete: :nothing)
    end

    alter table(:phenocodes_icd10s) do
      modify :phenocode_id, references(:phenocodes, on_delete: :delete_all), from: references(:phenocodes, on_delete: :nothing)
      modify :icd10_id, references(:icd10s, on_delete: :delete_all), from: references(:icd10s, on_delete: :nothing)
    end

    alter table(:phenocodes_icd9s) do
      modify :phenocode_id, references(:phenocodes, on_delete: :delete_all), from: references(:phenocodes, on_delete: :nothing)
      modify :icd9_id, references(:icd9s, on_delete: :delete_all), from: references(:icd9s, on_delete: :nothing)
    end
  end
end
