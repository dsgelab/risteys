defmodule Risteys.PhenocodeStats do
  use Ecto.Schema
  import Ecto.Changeset


  schema "phenocode_stats" do
    field :age_distribution, :map
    field :case_fatality_all, :float
    field :case_fatality_female, :float
    field :case_fatality_male, :float
    field :mean_age_all, :float
    field :mean_age_female, :float
    field :mean_age_male, :float
    field :median_reoccurence_all, :float
    field :median_reoccurence_female, :float
    field :median_reoccurence_male, :float
    field :prevalence_all, :float
    field :prevalence_female, :float
    field :prevalence_male, :float
    field :reoccurence_rate_all, :float
    field :reoccurence_rate_female, :float
    field :reoccurence_rate_male, :float
    field :year_distribution, :map
    field :phenocode_id, :id

    timestamps()
  end

  @doc false
  def changeset(phenocode_stats, attrs) do
    phenocode_stats
    |> cast(attrs, [:prevalence_all, :prevalence_female, :prevalence_male, :mean_age_all, :mean_age_female, :mean_age_male, :median_reoccurence_all, :median_reoccurence_female, :median_reoccurence_male, :reoccurence_rate_all, :reoccurence_rate_female, :reoccurence_rate_male, :case_fatality_all, :case_fatality_female, :case_fatality_male, :year_distribution, :age_distribution])
    |> validate_required([:prevalence_all, :prevalence_female, :prevalence_male, :mean_age_all, :mean_age_female, :mean_age_male, :median_reoccurence_all, :median_reoccurence_female, :median_reoccurence_male, :reoccurence_rate_all, :reoccurence_rate_female, :reoccurence_rate_male, :case_fatality_all, :case_fatality_female, :case_fatality_male, :year_distribution, :age_distribution])
  end
end
