defmodule Risteys.DrugStats do
  use Ecto.Schema
  import Ecto.Changeset

  schema "drug_stats" do
    field :phenocode_id, :id
    field :atc, :string

    field :name, :string
    field :score, :float
    field :stderr, :float
    field :pvalue, :float
    field :n_indivs, :integer

    timestamps()
  end

  @doc false
  def changeset(drug_stats, attrs) do
    drug_stats
    |> cast(attrs, [:phenocode_id, :atc, :name, :score, :stderr, :pvalue, :n_indivs])
    |> validate_required([:atc, :name, :score, :stderr])
    |> validate_number(:score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:stderr, greater_than_or_equal_to: 0.0)
    |> validate_number(:pvalue, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:n_indivs, greater_than: 5)  # no individual-level data
  end
end
