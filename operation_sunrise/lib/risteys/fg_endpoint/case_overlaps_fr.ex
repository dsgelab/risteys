defmodule Risteys.FGEndpoint.CaseOverlapsFR do
  use Ecto.Schema
  import Ecto.Changeset

  schema "case_overlaps_fr" do
    field :fg_endpoint_a_id, :id
    field :fg_endpoint_b_id, :id
    field :case_overlap_N, :integer
    field :case_overlap_percent, :float

    timestamps()
  end

  def changeset(case_overlaps_fr, attrs) do
    case_overlaps_fr
    |> cast(attrs, [
      :fg_endpoint_a_id,
      :fg_endpoint_b_id,
      :case_overlap_N,
      :case_overlap_percent
    ])
    |> validate_required([
      :fg_endpoint_a_id,
      :fg_endpoint_b_id,
      :case_overlap_N,
      :case_overlap_percent
    ])
    |> validate_number(:case_overlap_N, greater_than_or_equal_to: 0)
    |> validate_number(:case_overlap_percent, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> unique_constraint(:fg_endpoint_a_id, name: :fr_case_overlaps_fg_endpoint_a_b) # unique endpoint pair
  end
end
