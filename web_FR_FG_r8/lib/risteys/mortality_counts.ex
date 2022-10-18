defmodule Risteys.MortalityCounts do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mortality_counts" do
    field :fg_endpoint_id, :id
    field :exposed, :integer
    field :exposed_cases, :integer
    field :sex, :string

    timestamps()
  end

  def changeset(case_counts, attrs) do
    case_counts
    |> cast(attrs, [
      :fg_endpoint_id,
      :exposed,
      :exposed_cases,
      :sex
    ])
    |> validate_required([
      :fg_endpoint_id,
      :exposed,
      :exposed_cases,
      :sex
    ])
    |> validate_number(:exposed, greater_than_or_equal_to: 0)
    |> validate_number(:exposed_cases, greater_than_or_equal_to: 0)
    |> validate_inclusion(:sex, ["female", "male"])
    |> unique_constraint(:sex, name: :fg_endpoint_id_sex)
  end
end
