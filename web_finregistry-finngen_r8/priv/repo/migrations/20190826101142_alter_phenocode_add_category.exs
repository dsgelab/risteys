defmodule Risteys.Repo.Migrations.AlterPhenocodeAddCategory do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      add :category, :text
    end
  end
end
