defmodule Risteys.Repo.Migrations.AddIndexIcd10s do
  use Ecto.Migration

  def change do
    create unique_index(:icd10s, [:code])
  end
end
