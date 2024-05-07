defmodule Risteys.Repo.Migrations.AlterPhenocodeAddUpsetInfo do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      add :status_upset_plot, :text, null: false, default: "unknown"
      add :status_upset_table, :text, null: false, default: "unknown"
    end
  end
end
