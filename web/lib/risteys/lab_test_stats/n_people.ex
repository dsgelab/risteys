defmodule Risteys.LabTestStats.NPeople do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_test_stats_npeople" do
    field :female_count, :integer
    field :male_count, :integer

    # Not an OMOP concept ID, but a database ID
    field :omop_concept_dbid, :id

    timestamps()
  end

  @doc false
  def changeset(stats_npeople, attrs) do
    stats_npeople
    |> cast(attrs, [:female_count, :male_count, :omop_concept_dbid])
    |> validate_required([:omop_concept_dbid])
    |> validate_number(:female_count, greater_than_or_equal_to: 5)
    |> validate_number(:male_count, greater_than_or_equal_to: 5)
    |> unique_constraint([:omop_concept_dbid])
  end
end
