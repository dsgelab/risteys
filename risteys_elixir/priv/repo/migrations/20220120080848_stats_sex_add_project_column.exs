defmodule Risteys.Repo.Migrations.StatsSexAddProjectColumn do
  use Ecto.Migration

  def change do
    alter table(:stats_sex) do
      add :project, :string
    end
  end
end
