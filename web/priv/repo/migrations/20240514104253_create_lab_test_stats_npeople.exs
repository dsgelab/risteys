defmodule Risteys.Repo.Migrations.CreateLabTestStatsNpeople do
  use Ecto.Migration

  def change do
    create table(:lab_test_stats_npeople) do
      add :female_count, :integer
      add :male_count, :integer
      add :omop_concept_dbid, references(:omop_concepts, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:lab_test_stats_npeople, [:omop_concept_dbid])
  end
end
