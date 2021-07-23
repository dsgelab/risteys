defmodule Risteys.Repo.Migrations.AlterStatsSexModifyMedianType do
  use Ecto.Migration

  def change do
    alter table(:stats_sex) do
      modify :median_reoccurence, :float, from: :integer
    end
  end
end
