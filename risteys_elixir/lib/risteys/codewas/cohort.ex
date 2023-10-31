defmodule Risteys.CodeWAS.Cohort do
  use Ecto.Schema
  import Ecto.Changeset

  schema "codewas_cohort" do
    field :n_matched_cases, :integer
    field :n_matched_controls, :integer
    field :fg_endpoint_id, :id

    timestamps()
  end

  @doc false
  def changeset(cohort, attrs) do
    cohort
    |> cast(attrs, [:n_matched_cases, :n_matched_controls, :fg_endpoint_id])
    |> validate_required([:n_matched_cases, :n_matched_controls, :fg_endpoint_id])
    # For CodeWAS, the 2023-10 decision is to have cohort of minimum 50 people.
    |> validate_number(:n_matched_cases, greater_than_or_equal_to: 50)
    |> validate_number(:n_matched_controls, greater_than_or_equal_to: 50)
    |> unique_constraint(:codewas_cohort)
  end
end
