defmodule Risteys.Repo.Migrations.AlterMortalityParamsAddSex do
  use Ecto.Migration

  def up do
    alter table("mortality_params") do
      add :sex, :text
    end
    drop index(:mortality_params, [:fg_endpoint_id, :covariate], name: :covariate_fg_endpoint_id)
    create unique_index(:mortality_params, [:fg_endpoint_id, :covariate, :sex], name: :covariate_fg_endpoint_id_sex)
  end
  def down do
    drop index(:mortality_params, [:fg_endpoint_id, :covariate, :sex], name: :covariate_fg_endpoint_id_sex)
    create unique_index(:mortality_params, [:fg_endpoint_id, :covariate], name: :covariate_fg_endpoint_id)
    alter table("mortality_params") do
      remove :sex
    end
  end
end
