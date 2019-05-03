defmodule Risteys.Icd9 do
  use Ecto.Schema
  import Ecto.Changeset

  schema "icd9s" do
    field :code, :string
    field :description, :string

    many_to_many :phenocodes, Risteys.Phenocode, join_through: Risteys.PhenocodeIcd9

    timestamps()
  end

  @doc false
  def changeset(icd9, attrs) do
    icd9
    |> cast(attrs, [:code, :description])
    |> validate_required([:code, :description])
    |> unique_constraint(:code)
  end
end
