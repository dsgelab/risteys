defmodule Risteys.Repo.Migrations.AlterPhenocodesCoxHrsAddBch do
  use Ecto.Migration

  def change do
    alter table(:cox_hrs) do
      add :prior_coef, :float
      add :year_coef, :float
      add :sex_coef, :float
      add :prior_norm_mean, :float
      add :year_norm_mean, :float
      add :sex_norm_mean, :float
      add :bch_year_0, :float
      add :bch_year_2p5, :float
      add :bch_year_5, :float
      add :bch_year_7p5, :float
      add :bch_year_10, :float
      add :bch_year_12p5, :float
      add :bch_year_15, :float
      add :bch_year_17p5, :float
      add :bch_year_20, :float
      add :bch_year_21p99, :float
    end
  end
end
