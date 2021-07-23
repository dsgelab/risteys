defmodule Risteys.Repo.Migrations.CreateIcd10s do
  use Ecto.Migration

  def change do
    create table(:icd10s) do
      add :code, :string
      add :description, :string

      timestamps()
    end
  end
end
