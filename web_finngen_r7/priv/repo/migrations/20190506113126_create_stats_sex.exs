defmodule Risteys.Repo.Migrations.CreateStatsSex do
  use Ecto.Migration

  def change do
    create table(:stats_sex) do
      add :sex, :integer
      add :n_individuals, :integer
      add :prevalence, :float
      add :mean_age, :float
      add :median_reoccurence, :integer
      add :reoccurence_rate, :float
      add :case_fatality, :float
      add :phenocode_id, references(:phenocodes, on_delete: :nothing)

      timestamps()
    end

    create unique_index(:stats_sex, [:sex, :phenocode_id], name: :sex_phenocode_id)
  end
end
