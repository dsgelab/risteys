defmodule Risteys.Repo.Migrations.AlterPhenocodeRemoveH2 do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      remove :h2_liab, :float
      remove :h2_liab_se, :float
    end
  end
end
