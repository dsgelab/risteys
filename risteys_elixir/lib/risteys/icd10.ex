defmodule Risteys.Icd10 do
  use Ecto.Schema
  import Ecto.Changeset

  schema "icd10s" do
    field :code, :string
    field :description, :string

    timestamps()
  end

  @doc false
  def changeset(icd10, attrs) do
    icd10
    |> cast(attrs, [:code, :description])
    |> validate_required([:code, :description])
    |> unique_constraint(:code)
  end
end
