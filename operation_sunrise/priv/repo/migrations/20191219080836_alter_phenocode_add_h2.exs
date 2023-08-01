defmodule Risteys.Repo.Migrations.AlterPhenocodeAddH2 do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      add :h2_liab, :float
      add :h2_liab_se, :float
    end
  end
end
