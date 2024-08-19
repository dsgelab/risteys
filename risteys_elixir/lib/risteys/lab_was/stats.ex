defmodule Risteys.LabWAS.Stats do
  use Ecto.Schema
  import Ecto.Changeset

  schema "labwas_stats" do
    field :fg_endpoint_id, :id
    field :omop_concept_id, :string
    field :omop_concept_name, :string
    field :fg_endpoint_n_cases, :integer
    field :fg_endpoint_n_controls, :integer

    field :with_measurement_n_cases, :integer
    field :with_measurement_n_controls, :integer
    field :with_measurement_odds_ratio, :float
    field :with_measurement_mlogp, :float
    field :mean_n_measurements_cases, :float
    field :mean_n_measurements_controls, :float

    field :mean_value_n_cases, :integer
    field :mean_value_n_controls, :integer
    field :mean_value_unit, :string
    field :mean_value_cases, :float
    field :mean_value_controls, :float
    field :mean_value_mlogp, :float

    timestamps()
  end

  @doc false
  def changeset(stats, attrs) do
    stats
    |> cast(attrs, [
      :fg_endpoint_id,
      :omop_concept_id,
      :omop_concept_name,
      :fg_endpoint_n_cases,
      :fg_endpoint_n_controls,
      :with_measurement_n_cases,
      :with_measurement_n_controls,
      :with_measurement_odds_ratio,
      :with_measurement_mlogp,
      :mean_n_measurements_cases,
      :mean_n_measurements_controls,
      :mean_value_n_cases,
      :mean_value_n_controls,
      :mean_value_unit,
      :mean_value_cases,
      :mean_value_controls,
      :mean_value_mlogp
    ])
    |> validate_required([
      :fg_endpoint_id,
      :omop_concept_id,
      :fg_endpoint_n_cases,
      :fg_endpoint_n_controls,
      :with_measurement_n_cases,
      :with_measurement_n_controls,
      :with_measurement_odds_ratio,
      :with_measurement_mlogp,
      :mean_n_measurements_cases,
      :mean_n_measurements_controls
    ])
    |> validate_change(:fg_endpoint_n_cases, &validate_green/2)
    |> validate_change(:fg_endpoint_n_controls, &validate_green/2)
    |> validate_change(:with_measurement_n_cases, &validate_green/2)
    |> validate_change(:with_measurement_n_controls, &validate_green/2)
    |> validate_change(:mean_value_n_cases, &validate_green/2)
    |> validate_change(:mean_value_n_controls, &validate_green/2)
  end

  defp validate_green(field, value) do
    if not (value == 0 or value >= 5) do
      [{field, "value must be greater than or equal to 5, or 0."}]
    else
      []
    end
  end
end
