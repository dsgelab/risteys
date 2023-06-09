defmodule Risteys.Repo.Migrations.AlterPhenocodeRemoveOutpatBump do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      remove :outpat_bump, :boolean, default: false
    end
  end
end
