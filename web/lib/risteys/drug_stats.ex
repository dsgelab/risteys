defmodule Risteys.DrugStats do
  use Ecto.Schema
  import Ecto.Changeset

  schema "drug_stats" do
    field :fg_endpoint_id, :id
    field :atc_id, :id

    field :score, :float
    field :pvalue, :float
    field :stderr, :float
    field :n_indivs, :integer

    timestamps()
  end

  @doc false
  def changeset(drug_stats, attrs) do
    drug_stats
    |> cast(attrs, [:fg_endpoint_id, :atc_id, :score, :pvalue, :stderr, :n_indivs])
    |> validate_required([:score, :pvalue, :stderr, :n_indivs])
    |> validate_number(:score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:stderr, greater_than_or_equal_to: 0.0)
    |> validate_number(:pvalue, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:n_indivs, greater_than: 5)  # no individual-level data
  end
end
