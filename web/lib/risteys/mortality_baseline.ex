defmodule Risteys.MortalityBaseline do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mortality_baseline" do
    field :fg_endpoint_id, :id
    field :age, :float
    field :baseline_cumulative_hazard, :float
    field :sex, :string

    timestamps()
  end

  def changeset(mortality_baseline, attrs) do
    mortality_baseline
    |> cast(attrs, [
      :fg_endpoint_id,
      :age,
      :baseline_cumulative_hazard,
      :sex
    ])
    |> validate_required([
      :fg_endpoint_id,
      :age,
      :baseline_cumulative_hazard,
      :sex
    ])
    |> validate_inclusion(:sex, ["female", "male"])
    |> unique_constraint(:age, name: :age_fg_endpoint_id_sex)
  end
end
