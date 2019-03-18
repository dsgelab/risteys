defmodule Risteys.Repo.Migrations.CreateHealthEvents do
  use Ecto.Migration

  def change do
    create table(:health_events) do
      add :eid, :integer
      add :sex, :integer
      add :death, :boolean, default: false, null: false
      add :icd, :string
      add :dateevent, :date
      add :age, :float

      timestamps()
    end
  end
end
