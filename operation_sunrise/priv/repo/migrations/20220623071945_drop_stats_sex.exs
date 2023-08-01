defmodule Risteys.Repo.Migrations.DropStatsSex do
  use Ecto.Migration

  def up do
    drop table(:stats_sex)
  end

  def down do
    create table(:stats_sex) do
      add :sex, :integer
      add :fg_endpoint_id, references(:fg_endpoint_definitions, on_delete: :delete_all)
      add :median_age, :float
      add :n_individuals, :integer
      add :prevalence, :float
      add :distrib_year, :map
      add :distrib_age, :map
      add :dataset, :string

      timestamps()
    end

    create unique_index(:stats_sex, [:sex, :dataset, :fg_endpoint_id], name: :sex_dataset_fg_endpoint_id)
  end
end
