defmodule Risteys.Repo.Migrations.CreateLabTestStatsNpeople do
  use Ecto.Migration

  def change do
    create table(:lab_test_stats_npeople) do
      add :sex, :string, null: false
      add :count, :integer, null: false
      add :omop_concept_dbid, references(:omop_concepts, on_delete: :delete_all)

      timestamps()
    end

    create index(:lab_test_stats_npeople, [:omop_concept_dbid])
    create unique_index(:lab_test_stats_npeople, [:omop_concept_dbid, :sex], name: :uidx_lab_test_stats_npeople)
  end
end
