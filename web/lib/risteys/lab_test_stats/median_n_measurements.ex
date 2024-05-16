defmodule Risteys.LabTestStats.MedianNMeasurements do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_test_stats_median_n_measurements" do
    field :median_n_measurements, :float
    field :npeople, :integer
    field :omop_concept_dbid, :id

    timestamps()
  end

  @doc false
  def changeset(median_n_measurements, attrs) do
    median_n_measurements
    |> cast(attrs, [:median_n_measurements, :npeople, :omop_concept_dbid])
    |> validate_required([:median_n_measurements, :npeople, :omop_concept_dbid])
    |> validate_number(:median_n_measurements, greater_than_or_equal_to: 0)
    |> validate_number(:npeople, greater_than_or_equal_to: 5)
    |> unique_constraint([:omop_concept_dbid])
  end
end
