defmodule Risteys.StatsSex do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stats_sex" do
    field :case_fatality, :float
    field :sex, :integer
    field :mean_age, :float
    field :median_reoccurence, :integer
    field :n_individuals, :integer
    field :prevalence, :float
    field :reoccurence_rate, :float
    field :phenocode_id, :id

    timestamps()
  end

  @doc false
  def changeset(stats_sex, attrs) do
    stats_sex
    |> cast(attrs, [:sex, :n_individuals, :prevalence, :mean_age, :median_reoccurence, :reoccurence_rate, :case_fatality, :phenocode_id])
    |> validate_required([:sex, :n_individuals, :prevalence, :mean_age, :median_reoccurence, :reoccurence_rate, :case_fatality, :phenocode_id])
    |> validate_inclusion(:sex, [0, 1, 2])  # 0: all, 1: male, 2: female
    |> validate_number(:n_individuals, greater_than: 5)  # keep only non-individual level data
    |> validate_number(:prevalence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:mean_age, greater_than_or_equal_to: 0.0)
    |> validate_number(:median_reoccurence, greater_than_or_equal_to: 0)
    |> validate_number(:reoccurence_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint(:sex, name: :sex_phenocode_id)
  end
end
