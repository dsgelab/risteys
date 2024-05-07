defmodule Risteys.Repo.Migrations.AlterStatsSexMeanAgeToMedianAge do
  use Ecto.Migration

  def up do
    rename table(:stats_sex), :mean_age, to: :median_age
  end

  def down do
    rename table(:stats_sex), :median_age, to: :mean_age
  end
end
