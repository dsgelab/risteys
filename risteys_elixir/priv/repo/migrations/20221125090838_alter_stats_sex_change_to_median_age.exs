defmodule Risteys.Repo.Migrations.AlterStatsSexChangeToMedianAge do
  use Ecto.Migration

  def change do
    alter table(:stats_sex) do
      # Median age and mean age are different data, so we need to remove, not just rename the column
      remove :mean_age, :float

      add :median_age, :float
    end
  end
end
