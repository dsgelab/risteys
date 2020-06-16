# NOTE: This migration and the table structure is overseeded by a newer migration.

defmodule Risteys.Repo.Migrations.CreateDrugStats do
  use Ecto.Migration

  def change do
    create table(:drug_stats) do
      add :atc, :text, null: false
      add :name, :text, null: false
      add :score, :float, null: false
      add :stderr, :float, null: false
      add :pvalue, :float, null: false
      add :n_indivs, :integer, null: false
      add :phenocode_id, references(:phenocodes, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:drug_stats, [:phenocode_id, :atc], name: :phenocode_atc)
  end
end
