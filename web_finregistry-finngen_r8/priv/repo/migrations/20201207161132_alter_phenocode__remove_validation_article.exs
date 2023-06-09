defmodule Risteys.Repo.Migrations.AlterPhenocodeRemoveValidationArticle do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      remove :validation_article, :text
    end
  end
end
