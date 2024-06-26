defmodule Risteys.Repo.Migrations.CreateLabTestStatsDistributionValueRangePerPerson do
  use Ecto.Migration

  def change do
    create table(:lab_test_stats_distribution_value_range_per_person) do
      add :omop_concept_dbid, references(:omop_concepts, on_delete: :delete_all), null: false
      add :distribution, :map, nulL: false

      timestamps()
    end

    create unique_index(:lab_test_stats_distribution_value_range_per_person, [:omop_concept_dbid])
  end
end
