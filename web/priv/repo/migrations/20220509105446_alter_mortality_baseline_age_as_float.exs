defmodule Risteys.Repo.Migrations.AlterMortalityBaselineAgeAsFloat do
  use Ecto.Migration

  def change do
    alter table("mortality_baseline") do
      remove :age, :integer
      add :age, :float
    end
  end
end
