defmodule Risteys.AgeDistribution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "age_distribution" do
    field :fg_endpoint_id, :id
    field :sex, :string
    field :left, :float
    field :right, :float
    field :count, :integer
    field :dataset, :string

    timestamps()
  end

  def changeset(age_distribution, attrs) do
    age_distribution
    |> cast(attrs, [
      :fg_endpoint_id,
      :sex,
      :left,
      :right,
      :count,
      :dataset
    ])
    |> validate_required([:fg_endpoint_id, :sex, :dataset])
    |> validate_inclusion(:sex, ["all"])
    |> validate_inclusion(:dataset, ["FG", "FR"])
    |> validate_number(:count, greater_than_or_equal_to: 0)
    |> validate_exclusion(:count, 1..4)
    |> unique_constraint(:fg_endpoint_id, name: :age_distrib_fg_endpoint_id_left_dataset)
  end
end
