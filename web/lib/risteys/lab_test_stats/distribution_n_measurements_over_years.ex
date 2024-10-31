defmodule Risteys.LabTestStats.DistributionNMeasurementsOverYears do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_test_stats_distribution_n_measurements_over_years" do
    field :omop_concept_dbid, :id
    field :distribution, :map

    timestamps()
  end

  @doc false
  def changeset(distribution_n_measurements_over_years, attrs) do
    distribution_n_measurements_over_years
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
  end
end
