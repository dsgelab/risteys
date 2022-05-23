defmodule Risteys.PhenocodeIcd10 do
  use Ecto.Schema
  import Ecto.Changeset

  schema "phenocodes_icd10s" do
    field :registry, :string
    field :phenocode_id, :id
    field :icd10_id, :id

    timestamps()
  end

  @doc false
  def changeset(phenocode_icd10, attrs) do
    phenocode_icd10
    |> cast(attrs, [:registry, :phenocode_id, :icd10_id])
    |> validate_required([:registry, :phenocode_id, :icd10_id])
    |> unique_constraint(:registry, name: :phenocode_icd10_registry)
  end
end
