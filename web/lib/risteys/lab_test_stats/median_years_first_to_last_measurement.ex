defmodule Risteys.LabTestStats.MedianYearsFirstToLastMeasurement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_test_stats_median_years_first_to_last_measurement" do
    field :median_years_first_to_last_measurement, :float
    field :npeople, :integer
    field :omop_concept_dbid, :id

    timestamps()
  end

  @doc false
  def changeset(median_years_first_to_last_measurement, attrs) do
    median_years_first_to_last_measurement
    |> cast(attrs, [:median_years_first_to_last_measurement, :npeople, :omop_concept_dbid])
    |> validate_required([:median_years_first_to_last_measurement, :npeople, :omop_concept_dbid])
    |> validate_number(:median_years_first_to_last_measurement, greater_than_or_equal_to: 0)
    |> validate_number(:npeople, greater_than_or_equal_to: 5)
    |> unique_constraint([:omop_concept_dbid])
  end
end
