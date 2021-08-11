defmodule Risteys.Repo.Migrations.AlterCoxHrsRemoveBch do
  use Ecto.Migration

  def change do
    alter table(:cox_hrs) do
      remove :prior_coef, :float
      remove :year_coef, :float
      remove :sex_coef, :float
      remove :prior_norm_mean, :float
      remove :year_norm_mean, :float
      remove :sex_norm_mean, :float
      remove :bch_year_0, :float
      remove :bch_year_2p5, :float
      remove :bch_year_5, :float
      remove :bch_year_7p5, :float
      remove :bch_year_10, :float
      remove :bch_year_12p5, :float
      remove :bch_year_15, :float
      remove :bch_year_17p5, :float
      remove :bch_year_20, :float
      remove :bch_year_21p99, :float
    end
  end
end
