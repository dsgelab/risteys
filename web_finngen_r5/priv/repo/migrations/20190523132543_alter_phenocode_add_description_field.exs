defmodule Risteys.Repo.Migrations.AlterPhenocodeAddDescriptionField do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      add :description, :text
    end
  end
end
