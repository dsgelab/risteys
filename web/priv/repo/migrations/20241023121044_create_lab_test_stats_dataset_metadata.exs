defmodule Risteys.Repo.Migrations.CreateLabTestStatsDatasetMetadata do
  use Ecto.Migration

  def change do
    create table(:lab_test_stats_dataset_metadata) do
      add :npeople_alive, :integer, null: false

      timestamps()
    end
  end
end
