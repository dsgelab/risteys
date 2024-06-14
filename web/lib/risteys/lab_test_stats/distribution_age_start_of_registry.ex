defmodule Risteys.LabTestStats.DistributionAgeStartOfRegistry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_test_stats_distribution_age_start_of_registry" do
    field :omop_concept_dbid, :id
    field :distribution,  :map

    timestamps()
  end

  @doc false
  def changeset(distribution_age_start_of_registry, attrs) do
    distribution_age_start_of_registry
    |> cast(attrs, [:omop_concept_dbid, :distribution])
    |> validate_required([:omop_concept_dbid, :distribution])
    |> validate_change(:distribution, fn :distribution, dist ->
      Risteys.LabTestStats.validate_npeople_green(
        :distribution,
        dist,
        ["bins", Access.all()],
        "npeople"
      )
    end)
    |> unique_constraint([:omop_concept_dbid])
  end
end
