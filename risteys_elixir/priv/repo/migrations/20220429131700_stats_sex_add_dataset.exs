defmodule Risteys.Repo.Migrations.StatsSexAddDataset do
  use Ecto.Migration

  def up do
    alter table(:stats_sex) do
      add :dataset, :string
    end
    drop index(:stats_sex, [:sex, :fg_endpoint_id], name: :sex_fg_endpoint_id)
    create unique_index(:stats_sex, [:sex, :dataset, :fg_endpoint_id], name: :sex_dataset_fg_endpoint_id)
  end

  def down do
    drop index(:stats_sex, [:sex, :dataset, :fg_endpoint_id], name: :sex_dataset_fg_endpoint_id)
    create unique_index(:stats_sex, [:sex, :fg_endpoint_id], name: :sex_fg_endpoint_id)
    alter table(:stats_sex) do
      remove :dataset
    end
  end
end
