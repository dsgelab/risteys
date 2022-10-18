defmodule Risteys.MortalityParams do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mortality_params" do
    field :fg_endpoint_id, :id
    field :covariate, :string
    field :coef, :float
    field :ci95_lower, :float
    field :ci95_upper, :float
    field :p_value, :float
    field :mean, :float
    field :sex, :string

    timestamps()
  end

  def changeset(mortality_params, attrs) do
    mortality_params
    |> cast(attrs, [
      :fg_endpoint_id,
      :covariate,
      :coef,
      :ci95_lower,
      :ci95_upper,
      :p_value,
      :mean,
      :sex
    ])
    |> validate_required([
      :fg_endpoint_id,
      :covariate,
      :coef,
      :ci95_lower,
      :ci95_upper,
      :p_value,
      :mean,
      :sex
    ])
    |> validate_inclusion(:sex, ["female", "male"])
    |> unique_constraint(:covariate, name: :covariate_fg_endpoint_id_sex)
  end
end
