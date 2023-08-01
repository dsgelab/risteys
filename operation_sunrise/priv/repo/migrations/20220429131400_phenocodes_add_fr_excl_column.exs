defmodule Risteys.Repo.Migrations.PhenocodesAddFrExclColumn do
  use Ecto.Migration

  def change do
    alter table(:fg_endpoint_definitions) do
      add :fr_excl, :string
    end
  end
end
