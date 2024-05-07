defmodule Risteys.Repo.Migrations.AlterPhenocodeAddFieldsR5 do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      add :hd_icd_10_atc, :text
      add :latin, :text
    end
  end
end
