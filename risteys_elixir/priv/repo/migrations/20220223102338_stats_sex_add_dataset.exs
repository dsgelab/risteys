defmodule Risteys.Repo.Migrations.StatsSexAddDataset do
  use Ecto.Migration

  def up do
    alter table(:stats_sex) do
      add :dataset, :string
    end
    drop index(:stats_sex, [:sex, :phenocode_id], name: :sex_phenocode_id)
    create unique_index(:stats_sex, [:sex, :dataset, :phenocode_id], name: :sex_dataset_phenocode_id)
  end

  def down do
    drop index(:stats_sex, [:sex, :dataset, :phenocode_id], name: :sex_dataset_phenocode_id)
    create unique_index(:stats_sex, [:sex, :phenocode_id], name: :sex_phenocode_id)
    alter table(:stats_sex) do
      remove :dataset
    end
  end
end
