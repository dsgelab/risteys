defmodule Risteys.Repo.Migrations.AlterPhenocodeAddGwsHits do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      add :gws_hits, :integer
    end
  end
end
