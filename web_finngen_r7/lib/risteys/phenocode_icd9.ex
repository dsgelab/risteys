defmodule Risteys.PhenocodeIcd9 do
  use Ecto.Schema
  import Ecto.Changeset

  schema "phenocodes_icd9s" do
    field :registry, :string
    field :phenocode_id, :id
    field :icd9_id, :id

    timestamps()
  end

  @doc false
  def changeset(phenocode_icd9, attrs) do
    phenocode_icd9
    |> cast(attrs, [:registry, :phenocode_id, :icd9_id])
    |> validate_required([:registry, :phenocode_id, :icd9_id])
    |> unique_constraint(:registry, name: :phenocode_icd9_registry)
  end
end
