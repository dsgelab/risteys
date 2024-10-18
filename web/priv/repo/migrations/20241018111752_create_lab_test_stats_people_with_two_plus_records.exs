defmodule Risteys.Repo.Migrations.CreateLabTestStatsPeopleWithTwoPlusRecords do
  use Ecto.Migration

  def change do
    create table(:lab_test_stats_people_with_two_plus_records) do
      add :percent_people, :float, null: false
      add :npeople, :integer, null: false
      add :omop_concept_dbid, references(:omop_concepts, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:lab_test_stats_people_with_two_plus_records, [:omop_concept_dbid])
  end
end
