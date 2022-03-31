defmodule Risteys.MortalityBaseline do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mortality_baseline" do
    field :fg_endpoint_id, :id
    field :age, :integer
    field :baseline_cumulative_hazard, :float

    timestamps()
  end

  def changeset(mortality_baseline, attrs) do
    mortality_baseline
    |> cast(attrs, [
      :fg_endpoint_id,
      :age,
      :baseline_cumulative_hazard
    ])
    |> validate_required([
      :fg_endpoint_id,
      :age,
      :baseline_cumulative_hazard
    ])
    |> unique_constraint(:age, name: :age_fg_endpoint_id)
  end
end
