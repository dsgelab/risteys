defmodule Risteys.Repo.Migrations.StatsSexAlterUniqueConstraint do
  use Ecto.Migration

  def up do
    drop index(:stats_sex, [:sex, :phenocode_id], name: :sex_phenocode_id)
    create unique_index(:stats_sex, [:sex, :project, :phenocode_id], name: :sex_project_phenocode_id)
  end

  def down do
    drop index(:stats_sex, [:sex,  :project, :phenocode_id], name: :sex_project_phenocode_id)
    create unique_index(:stats_sex, [:sex, :phenocode_id], name: :sex_phenocode_id)
  end
end
