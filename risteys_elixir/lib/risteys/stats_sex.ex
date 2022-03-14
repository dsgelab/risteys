defmodule Risteys.StatsSex do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stats_sex" do
    field :sex, :integer
    field :fg_endpoint_id, :id

    field :mean_age, :float
    field :n_individuals, :integer
    field :prevalence, :float
    # can't specify more than ':map' since composite types
    field :distrib_year, :map
    field :distrib_age, :map

    timestamps()
  end

  @doc false
  def changeset(stats_sex, attrs) do
    stats_sex
    |> cast(attrs, [
      :sex,
      :n_individuals,
      :prevalence,
      :mean_age,
      :fg_endpoint_id,
      :distrib_year,
      :distrib_age
    ])
    |> validate_required([:sex, :fg_endpoint_id])
    # 0: all, 1: male, 2: female
    |> validate_inclusion(:sex, [0, 1, 2])
    # keep only non-individual level data
    |> validate_number(:n_individuals, greater_than_or_equal_to: 0)
    |> validate_exclusion(:n_individuals, 1..4)
    |> validate_number(:prevalence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:mean_age, greater_than_or_equal_to: 0.0)
    |> validate_change(:distrib_year, fn :distrib_year, %{hist: hist} ->
      check_distrib(hist)
    end)
    |> validate_change(:distrib_age, fn :distrib_age, %{hist: hist} -> check_distrib(hist) end)
    |> unique_constraint(:sex, name: :sex_fg_endpoint_id)
  end

  defp check_distrib(hist) do
    errors =
      for [bin, value] <- hist do
        if value in 1..4 do
          {:distrib, "bin #{bin} value #{value} in 1..4"}
        end
      end

    Enum.reject(errors, fn error -> is_nil(error) end)
  end
end
