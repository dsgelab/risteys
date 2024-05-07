defmodule Risteys.Repo.Migrations.CreateStatsCumulativeIncidence do
  use Ecto.Migration

  def change do
    create table(:stats_cumulative_incidence) do
      add :age, :float, null: false
      add :sex, :text, null: false
      add :value, :float, null: false
      add :phenocode_id, references(:phenocodes, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:stats_cumulative_incidence, [:phenocode_id, :sex, :age], name: :cumulinc)
  end
end
