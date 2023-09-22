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
    |> validate_change(:n_matched_cases, &Risteys.Utils.is_green/2)
    |> validate_change(:n_matched_controls, &Risteys.Utils.is_green/2)
    |> unique_constraint(:codewas_cohort)
  end
end
