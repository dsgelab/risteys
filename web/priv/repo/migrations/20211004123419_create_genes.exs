defmodule Risteys.Repo.Migrations.CreateGenes do
  use Ecto.Migration

  def change do
    create table(:genes) do
      add :ensid, :text
      add :name, :text
      add :chromosome, :text
      add :start, :integer
      add :stop, :integer

      timestamps()
    end

    create unique_index(:genes, [:ensid])
    create index(:genes, [:chromosome])
  end
end
