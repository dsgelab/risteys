defmodule Risteys.Repo.Migrations.CreateYearDistribution do
  use Ecto.Migration

  def change do
    create table(:year_distribution) do
      add :fg_endpoint_id, references(:fg_endpoint_definitions, on_delete: :delete_all)
      add :sex, :string
      add :left, :float
      add :right, :float
      add :count, :integer
      add :dataset, :string

      timestamps()
    end

    create unique_index(:year_distribution, [:fg_endpoint_id, :left, :dataset], name: :fg_endpoint_id_left_dataset)
  end
end
