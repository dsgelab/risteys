defmodule Risteys.Repo.Migrations.AlterPhenocodeAddOutpatBump do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      add :outpat_bump, :boolean, null: false, default: false
    end
  end
end
