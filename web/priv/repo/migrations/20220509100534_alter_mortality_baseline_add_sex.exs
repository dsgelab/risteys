defmodule Risteys.Repo.Migrations.AlterMortalityBaselineAddSex do
  use Ecto.Migration

  def up do
    alter table("mortality_baseline") do
      add :sex, :text
    end
    drop index(:mortality_baseline, [:fg_endpoint_id, :age], name: :age_fg_endpoint_id)
    create unique_index(:mortality_baseline, [:fg_endpoint_id, :age, :sex], name: :age_fg_endpoint_id_sex)
  end

  def down do
    drop index(:mortality_baseline, [:fg_endpoint_id, :age, :sex], name: :age_fg_endpoint_id_sex)
    create unique_index(:mortality_baseline, [:fg_endpoint_id, :age], name: :age_fg_endpoint_id)
    alter table("mortality_baseline") do
      remove :sex
    end
  end
end
