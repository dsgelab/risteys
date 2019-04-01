defmodule Risteys.Repo.Migrations.AlterPhenocodesAddDescriptionHpoxref do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      add :description, :text
      add :hpo_xref, :string
    end
  end
end
