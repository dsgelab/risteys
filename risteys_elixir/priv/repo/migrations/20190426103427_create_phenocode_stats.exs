defmodule Risteys.Repo.Migrations.CreatePhenocodeStats do
  use Ecto.Migration

  def change do
    create table(:phenocode_stats) do
      add :prevalence_all, :float
      add :prevalence_female, :float
      add :prevalence_male, :float
      add :mean_age_all, :float
      add :mean_age_female, :float
      add :mean_age_male, :float
      add :median_reoccurence_all, :float
      add :median_reoccurence_female, :float
      add :median_reoccurence_male, :float
      add :reoccurence_rate_all, :float
      add :reoccurence_rate_female, :float
      add :reoccurence_rate_male, :float
      add :case_fatality_all, :float
      add :case_fatality_female, :float
      add :case_fatality_male, :float
      add :year_distribution, :map
      add :age_distribution, :map
      add :phenocode_id, references(:phenocodes, on_delete: :nothing)

      timestamps()
    end

    create index(:phenocode_stats, [:phenocode_id])
  end
end
