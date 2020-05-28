defmodule Risteys.StatsSex do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stats_sex" do
    field :sex, :integer
    field :phenocode_id, :id

    field :case_fatality, :float
    field :mean_age, :float
    field :median_reoccurence, :float
    field :n_individuals, :integer
    field :prevalence, :float
    field :reoccurence_rate, :float
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
      :median_reoccurence,
      :reoccurence_rate,
      :case_fatality,
      :phenocode_id,
      :distrib_year,
      :distrib_age
    ])
    |> validate_required([:sex, :phenocode_id])
    # 0: all, 1: male, 2: female
    |> validate_inclusion(:sex, [0, 1, 2])
    # keep only non-individual level data
    |> validate_number(:n_individuals, greater_than: 5)
    |> validate_number(:prevalence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:mean_age, greater_than_or_equal_to: 0.0)
    |> validate_number(:median_reoccurence, greater_than_or_equal_to: 0)
    |> validate_number(:reoccurence_rate,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> validate_change(:distrib_year, fn :distrib_year, %{hist: hist} ->
      check_distrib(hist)
    end)
    |> validate_change(:distrib_age, fn :distrib_age, %{hist: hist} -> check_distrib(hist) end)
    |> unique_constraint(:sex, name: :sex_phenocode_id)
  end

  defp check_distrib(hist) do
    indiv_treshold = 6

    errors =
      for [bin, value] <- hist do
        if value < indiv_treshold and floor(value) != 0 do
          {:distrib, "bin #{bin} value #{value} < #{indiv_treshold} but not = 0"}
        end
      end

    Enum.reject(errors, fn error -> is_nil(error) end)
  end
end
