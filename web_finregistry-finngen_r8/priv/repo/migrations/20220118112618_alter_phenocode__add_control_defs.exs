defmodule Risteys.Repo.Migrations.AlterPhenocodeAddControlDefs do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      add :control_exclude, :text
      add :control_preconditions, :text
      add :control_conditions, :text
    end
  end
end
