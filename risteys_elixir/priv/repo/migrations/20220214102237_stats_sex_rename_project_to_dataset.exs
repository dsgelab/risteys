defmodule Risteys.Repo.Migrations.StatsSexRenameProjectToDataset do
  use Ecto.Migration

  def up do
    drop index(:stats_sex, [:sex, :project, :phenocode_id], name: :sex_project_phenocode_id)
    rename table(:stats_sex), :project, to: :dataset
    create unique_index(:stats_sex, [:sex, :dataset, :phenocode_id], name: :sex_dataset_phenocode_id)
  end

  def down do
    drop index(:stats_sex, [:sex, :dataset, :phenocode_id], name: :sex_dataset_phenocode_id)
    rename table(:stats_sex), :dataset, to: :project
    create unique_index(:stats_sex, [:sex, :project, :phenocode_id], name: :sex_project_phenocode_id)
  end
end
