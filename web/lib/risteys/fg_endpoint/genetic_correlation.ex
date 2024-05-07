defmodule Risteys.FGEndpoint.GeneticCorrelation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "genetic_correlations" do
    field :fg_endpoint_a_id, :id
    field :fg_endpoint_b_id, :id
    field :rg, :float
    field :se, :float
    field :pvalue, :float

    timestamps()
  end

  def changeset(genetic_correlation, attrs) do
    genetic_correlation
    |> cast(attrs, [
      :fg_endpoint_a_id,
      :fg_endpoint_b_id,
      :rg,
      :se,
      :pvalue,
    ])
    |> validate_required([])
    |> validate_number(:pvalue, less_than: 1)
    |> unique_constraint(:fg_endpoint_a_id, name: :gen_corr_fg_endpoint_a_b) # unique endpoint pair
  end
end
