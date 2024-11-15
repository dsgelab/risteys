defmodule Risteys.KeyFigures do
  use Ecto.Schema
  import Ecto.Changeset

  schema "key_figures" do
    field :fg_endpoint_id, :id
    field :nindivs_all, :integer
    field :nindivs_female, :integer
    field :nindivs_male, :integer
    field :median_age_all, :float
    field :median_age_female, :float
    field :median_age_male, :float
    field :prevalence_all, :float
    field :prevalence_female, :float
    field :prevalence_male, :float
    field :dataset, :string

    timestamps()
  end

  def changeset(key_figures, attrs) do
    key_figures
    |> cast(attrs, [
      :fg_endpoint_id,
      :nindivs_all,
      :nindivs_female,
      :nindivs_male,
      :median_age_all,
      :median_age_female,
      :median_age_male,
      :prevalence_all,
      :prevalence_female,
      :prevalence_male,
      :dataset
    ])
    |> validate_required([:fg_endpoint_id, :dataset])
    |> validate_number(:nindivs_all, greater_than_or_equal_to: 0)
    |> validate_exclusion(:nindivs_all, 1..4)
    |> validate_number(:nindivs_female, greater_than_or_equal_to: 0)
    |> validate_exclusion(:nindivs_female, 1..4)
    |> validate_number(:nindivs_male, greater_than_or_equal_to: 0)
    |> validate_exclusion(:nindivs_male, 1..4)
    |> validate_number(:median_age_all,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 120.0
    )
    |> validate_number(:median_age_female,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 120.0
    )
    |> validate_number(:median_age_male,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 120.0
    )
    |> validate_number(:prevalence_all,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 100.0
    )
    |> validate_number(:prevalence_female,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 100.0
    )
    |> validate_number(:prevalence_male,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 100.0
    )
    |> validate_inclusion(:dataset, ["FG", "FR", "FR_index"])
    |> unique_constraint([:fg_endpoint_id, :dataset], name: :key_figures_fg_endpoint_id_dataset)
  end
end
