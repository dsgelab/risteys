defmodule Risteys.Repo.Migrations.DropHealthEvents do
  use Ecto.Migration

  def up do
    drop table(:health_events)
  end

  def down do
    create table(:health_events) do
      add :eid, :integer
      add :sex, :integer
      add :death, :boolean, default: false, null: false
      add :dateevent, :date
      add :age, :float
      add :phenocode_id, references(:phenocodes, on_delete: :nothing)

      timestamps()
    end

    create index(:health_events, [:phenocode_id])
  end
end
