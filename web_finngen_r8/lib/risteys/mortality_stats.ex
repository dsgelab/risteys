defmodule Risteys.MortalityStats do
  use Ecto.Schema
  import Ecto.Changeset

  schema "mortality_stats" do
    field :phenocode_id, :id
    field :lagged_hr_cut_year, :integer

    field :hr, :float
    field :hr_ci_min, :float
    field :hr_ci_max, :float
    field :pvalue, :float
    field :n_individuals, :integer
    field :absolute_risk, :float

    timestamps()
  end

  @doc false
  def changeset(mortality_stats, attrs) do
    mortality_stats
    |> cast(attrs, [:phenocode_id, :lagged_hr_cut_year, :hr, :hr_ci_min, :hr_ci_max, :pvalue, :n_individuals, :absolute_risk])
    |> validate_required([:phenocode_id, :lagged_hr_cut_year, :hr, :hr_ci_min, :hr_ci_max, :pvalue, :n_individuals, :absolute_risk])
    |> validate_inclusion(:lagged_hr_cut_year, [0, 1, 5, 15])
    |> validate_number(:hr, greater_than_or_equal_to: 0.0)
    |> validate_number(:pvalue, greater_than_or_equal_to: 0.0, less_than: 1)
    |> validate_number(:n_individuals, greater_than: 5)
    |> validate_number(:absolute_risk, greater_than_or_equal_to: 0.0, less_than: 1)
    |> unique_constraint(:phenocode_id, name: :phenocode_hrlag)
  end
end
