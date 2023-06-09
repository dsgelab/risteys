defmodule Risteys.Repo.Migrations.AlterStatsSexRemoveCaseFatality do
  use Ecto.Migration

  def change do
    alter table(:stats_sex) do
      remove :case_fatality, :float
    end
  end
end
