defmodule Risteys.Repo.Migrations.AlterPhenocodeStatsSexMoveDistribs do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      remove :distrib_year, :map
      remove :distrib_age, :map
    end

    alter table(:stats_sex) do
      add :distrib_year, :map
      add :distrib_age, :map
    end
  end
end
