defmodule Risteys.FGEndpoint.Correlation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "correlations" do
    field :phenocode_a_id, :id
    field :phenocode_b_id, :id

    field :case_ratio, :float
    field :shared_of_a, :float
    field :shared_of_b, :float
    field :coloc_gws_hits_same_dir, :integer
    field :coloc_gws_hits_opp_dir, :integer
    field :rel_beta, :float
    field :rel_beta_opp_dir, :float

    timestamps()
  end

  @doc false
  def changeset(correlation, attrs) do
    correlation
    |> cast(attrs, [
      :phenocode_a_id,
      :phenocode_b_id,
      :case_ratio,
      :shared_of_a,
      :shared_of_b,
      :coloc_gws_hits_same_dir,
      :coloc_gws_hits_opp_dir,
      :rel_beta,
      :rel_beta_opp_dir
    ])
    |> validate_required([])
    |> validate_number(:case_ratio, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:shared_of_a, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:shared_of_b, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint(:phenocode_a_id, name: :phenocode_a_b)
  end
end
