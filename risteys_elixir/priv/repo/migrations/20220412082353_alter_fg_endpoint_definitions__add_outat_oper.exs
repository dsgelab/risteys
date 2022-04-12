defmodule Risteys.Repo.Migrations.AlterFgEndpointDefinitionsAddOutatOper do
  use Ecto.Migration

  def change do
    alter table("fg_endpoint_definitions") do
      add :outpat_oper, :text
    end
  end
end
