defmodule Risteys.Repo.Migrations.AlterDrugStatsSplitName do
  use Ecto.Migration

  def up do
    # Need to recreate the Drug Stats table as we are changing the ATC
    # column. This column was part of the primary key for this table,
    # in its transient state the rows lose the information to which
    # actual ATC it refers to, rendering the rows unusable. By
    # recreating the table, we ensure the table is never in a bad
    # transient state were data could be made unreachable.
    drop table(:drug_stats)

    create table(:atc_drugs) do
      add :atc, :text
      add :description, :text

      timestamps()
    end

    create unique_index(:atc_drugs, [:atc])

    create table(:drug_stats) do
      add :score, :float, null: false
      add :stderr, :float, null: false
      add :pvalue, :float, null: false
      add :n_indivs, :integer, null: false

      add :atc_id, references(:atc_drugs, on_delete: :delete_all)
      add :phenocode_id, references(:phenocodes, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:drug_stats, [:phenocode_id, :atc_id], name: :phenocode_atc)
  end

  def down do
    # Reverse: create unique_index(:drug_stats, [:phenocode_id, :atc_id], name: :phenocode_atc))
    drop index(:drug_stats, [:phenocode_id, :atc_id], name: :phenocode_atc)

    # Reverse: create table(:drug_stats)
    drop table(:drug_stats)

    # Reverse: create unique_index(:atc_drugs, [:atc])
    drop index(:atc_drugs, [:atc])

    # Reverse: create table(:atc_drugs)
    drop table(:atc_drugs)

    # Reverse: drop table(:drug_stats)
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
