defmodule Risteys.LabTestStats.DistributionValueRangePerPerson do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_test_stats_distribution_value_range_per_person" do
    field :omop_concept_dbid, :id
    field :distribution, :map

    timestamps()
  end

  @doc false
  def changeset(distribution_value_range_per_person, attrs) do
    distribution_value_range_per_person
    |> cast(attrs, [:omop_concept_dbid, :distribution])
    |> validate_required([:omop_concept_dbid, :distribution])
  end
end
