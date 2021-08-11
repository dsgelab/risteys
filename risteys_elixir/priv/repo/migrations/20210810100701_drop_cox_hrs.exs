defmodule Risteys.Repo.Migrations.DropCoxHrs do
  use Ecto.Migration

  def change do
    drop_if_exists table("cox_hrs")

  end
end
