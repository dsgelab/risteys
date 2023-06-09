defmodule Risteys.Repo.Migrations.StatsCumulativeIncidenceAddDataset do
  use Ecto.Migration

  def up do
    alter table(:stats_cumulative_incidence) do
      add :dataset, :string
    end
    drop index(:stats_cumulative_incidence, [:fg_endpoint_id, :sex, :age], name: :cumulinc)
    create unique_index(:stats_cumulative_incidence, [:fg_endpoint_id, :sex, :age, :dataset], name: :cumulinc)
  end

  def down do
    drop index(:stats_cumulative_incidence, [:fg_endpoint_id, :sex, :age, :dataset], name: :cumulinc)
    create unique_index(:stats_cumulative_incidence, [:fg_endpoint_id, :sex, :age], name: :cumulinc)
    alter table(:stats_cumulative_incidence) do
      remove :dataset
    end
  end
end
