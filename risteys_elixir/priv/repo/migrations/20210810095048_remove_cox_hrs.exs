defmodule Risteys.Repo.Migrations.RemoveCoxHrs do
  use Ecto.Migration

  def change do
    drop_if_exists table("cor_hrs")

  end
end
