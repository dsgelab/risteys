defmodule Risteys.Repo.Migrations.AlterPhenocodesModifyDistribs do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      modify :distrib_year, :map, from: {:map, :integer}
      modify :distrib_age, :map, from: {:map, :integer}
    end
  end
end
