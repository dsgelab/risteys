defmodule Risteys.CoxHR do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cox_hrs" do
    field :prior_id, :id
    field :outcome_id, :id
    field :lagged_hr_cut_year, :integer

    field :hr, :float
    field :ci_max, :float
    field :ci_min, :float
    field :n_individuals, :integer
    field :pvalue, :float

    field :prior_coef, :float
    field :year_coef, :float
    field :sex_coef, :float
    field :prior_norm_mean, :float
    field :year_norm_mean, :float
    field :sex_norm_mean, :float
    field :bch_year_0, :float
    field :bch_year_2p5, :float
    field :bch_year_5, :float
    field :bch_year_7p5, :float
    field :bch_year_10, :float
    field :bch_year_12p5, :float
    field :bch_year_15, :float
    field :bch_year_17p5, :float
    field :bch_year_20, :float
    field :bch_year_21p99, :float

    timestamps()
  end

  @doc false
  def changeset(cox_hr, attrs) do
    cox_hr
    |> cast(attrs, [
	  :prior_id,
	  :outcome_id,
	  :lagged_hr_cut_year,
	  :hr,
	  :ci_min,
	  :ci_max,
	  :n_individuals,
	  :pvalue,
	  :prior_coef,
	  :year_coef,
	  :sex_coef,
	  :prior_norm_mean,
	  :year_norm_mean,
	  :sex_norm_mean,
	  :bch_year_0,
	  :bch_year_2p5,
	  :bch_year_5,
	  :bch_year_7p5,
	  :bch_year_10,
	  :bch_year_12p5,
	  :bch_year_15,
	  :bch_year_17p5,
	  :bch_year_20,
	  :bch_year_21p99
	])
    |> validate_inclusion(:lagged_hr_cut_year, [0, 1, 5, 15])
    |> validate_number(:n_individuals, greater_than: 5)
    |> validate_number(:pvalue, less_than: 1)
    |> validate_required([:hr, :ci_min, :ci_max, :n_individuals, :pvalue])
    |> unique_constraint(:prior_id, name: :prior_outcome_laggedhr)
  end
end
