defmodule Risteys.Repo.Migrations.AlterStatsSexRemoveRecs do
  use Ecto.Migration

  def change do
    alter table(:stats_sex) do
      remove :median_reoccurence, :float
      remove :reoccurence_rate, :float
    end
  end
end
