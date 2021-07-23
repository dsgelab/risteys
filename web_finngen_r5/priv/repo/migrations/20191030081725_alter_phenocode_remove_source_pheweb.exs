defmodule Risteys.Repo.Migrations.AlterPhenocodeRemoveSourcePheweb do
  use Ecto.Migration

  def change do
    alter table(:phenocodes) do
      remove :source, :text, default: nil
      remove :pheweb, :boolean, default: nil
    end
  end
end
