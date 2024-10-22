defmodule Risteys.Repo.Migrations.ChangeLabTestStatsDistributionsLabValuesBinsDataStructure do
  use Ecto.Migration

  def up do
    alter table(:lab_test_stats_distributions_lab_values) do
      remove :distributions
      add :bins, {:array, :map}, null: false, default: []
      add :unit, :string, null: false, default: ""
      add :break_min, :float, null: true
      add :break_max, :float, null: true
    end
  end

  def down do
    alter table(:lab_test_stats_distributions_lab_values) do
      remove :break_max
      remove :break_min
      remove :unit
      remove :bins
      add :distributions, {:array, :map}, null: false, default: []
    end
  end
end
