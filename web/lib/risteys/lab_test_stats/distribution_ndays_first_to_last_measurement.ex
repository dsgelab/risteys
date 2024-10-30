defmodule Risteys.LabTestStats.DistributionNYearsFirstToLastMeasurement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_test_stats_distribution_nyears_first_to_last_measurement" do
    field :omop_concept_dbid, :id
    field :distribution, :map

    timestamps()
  end

  @doc false
  def changeset(distribution_duration_first_to_last_measurement, attrs) do
    distribution_duration_first_to_last_measurement
    |> cast(attrs, [:omop_concept_dbid, :distribution])
    |> validate_required([:omop_concept_dbid, :distribution])
    |> validate_change(:distribution, fn :distribution, dist ->
      Risteys.LabTestStats.validate_npeople_green(
        :distribution,
        dist,
        [:bins, Access.all()],
        :npeople
      )
    end)
    |> unique_constraint([:omop_concept_dbid])
  end
end
