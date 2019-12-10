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

    timestamps()
  end

  @doc false
  def changeset(cox_hr, attrs) do
    cox_hr
    |> cast(attrs, [:prior_id, :outcome_id, :lagged_hr_cut_year, :hr, :ci_min, :ci_max, :n_individuals, :pvalue])
    |> validate_inclusion(:lagged_hr_cut_year, [0, 1, 5, 15])
    |> validate_number(:n_individuals, greater_than: 5)
    |> validate_number(:pvalue, less_than: 1)
    |> validate_required([:hr, :ci_min, :ci_max, :n_individuals, :pvalue])
    |> unique_constraint(:prior_id, name: :prior_outcome_laggedhr)
  end
end
