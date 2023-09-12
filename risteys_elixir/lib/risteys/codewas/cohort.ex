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
    |> validate_change(:n_matched_cases, &is_green/2)
    |> validate_change(:n_matched_controls, &is_green/2)
    |> unique_constraint(:codewas_cohort)
  end

  defp is_green(field, value) do
    if value == 0 or value >= 5 do
      []
    else
      [{field, "#{field} must be 0 or ≥5 but is #{value}."}]
    end
  end
end
