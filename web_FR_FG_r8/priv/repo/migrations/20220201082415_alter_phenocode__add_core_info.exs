defmodule Risteys.Repo.Migrations.AlterPhenocodeAddCoreInfo do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      add :is_core, :boolean, null: false, default: false
      add :reason_non_core, :text
      add :selected_core_id, references(:phenocodes, on_delete: :nothing)
    end
  end
end
