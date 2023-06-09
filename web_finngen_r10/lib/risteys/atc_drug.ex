defmodule Risteys.ATCDrug do
  use Ecto.Schema
  import Ecto.Changeset

  schema "atc_drugs" do
    field :atc, :string
    field :description, :string

    timestamps()
  end

  @doc false
  def changeset(atc_drug, attrs) do
    atc_drug
    |> cast(attrs, [:atc, :description])
    |> validate_required([:atc, :description])
    |> unique_constraint(:atc)
  end
end
