defmodule Risteys.Repo.Migrations.CreateIcd9s do
  use Ecto.Migration

  def change do
    create table(:icd9s) do
      add :code, :string
      add :description, :string

      timestamps()
    end

    create unique_index(:icd9s, [:code])
  end
end
