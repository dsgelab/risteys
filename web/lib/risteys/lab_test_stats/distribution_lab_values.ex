defmodule Risteys.LabTestStats.DistributionLabValues do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_test_stats_distributions_lab_values" do
    field :omop_concept_dbid, :id
    # The "bins" field has this data structure for continuous distributions:
    # [
    #   %{x1: ..., x2: ..., y: ..., x_formatted: ..., y_formatted: ..., npeople: ...},
    #   %{x1: ..., x2: ..., y: ..., x_formatted: ..., y_formatted: ..., npeople: ...},
    #   ...
    # ]
    #
    # And this data structure for discrete distributions:
    # [
    #   %{x: ..., y: ..., npeople: ...}
    # ]
    field :bins, {:array, :map}
    field :unit, :string

    # Not defined for discrete distributions
    field :break_min, :float
    # Not defined for discrete distributions
    field :break_max, :float

    timestamps()
  end

  @doc false
  def changeset(distribution, attrs) do
    distribution
    |> cast(attrs, [:omop_concept_dbid, :bins, :unit, :break_min, :break_max])
    |> validate_required([:omop_concept_dbid, :bins, :unit])
    |> validate_change(:bins, fn :bins, bins -> validate_bins_npeople(bins) end)
    |> unique_constraint([:omop_concept_dbid])
  end

  defp validate_bins_npeople(bins) do
    Risteys.LabTestStats.validate_npeople_green(
      :bins,
      bins,
      [Access.all()],
      :npeople
    )
  end
end
