defmodule Risteys.CoxHR do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cox_hrs" do
    field :ci_max, :float
    field :ci_min, :float
    field :hr, :float
    field :n_individuals, :integer
    field :prior_id, :id
    field :pvalue, :float
    field :outcome_id, :id

    timestamps()
  end

  @doc false
  def changeset(cox_hr, attrs) do
    cox_hr
    |> cast(attrs, [:hr, :ci_min, :ci_max, :n_individuals, :pvalue, :prior_id, :outcome_id])
    |> validate_number(:n_individuals, greater_than: 5)
    |> validate_number(:pvalue, less_than: 1)
    |> validate_required([:hr, :ci_min, :ci_max, :n_individuals, :pvalue])
    |> unique_constraint(:prior_id, name: :prior_outcome)
  end
end
