defmodule Risteys.FGEndpoint.DefinitionICD10 do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fg_endpoint_definitions_icd10s" do
    field :registry, :string
    field :fg_endpoint_id, :id
    field :icd10_id, :id

    timestamps()
  end

  @doc false
  def changeset(fg_endpoint_icd10, attrs) do
    fg_endpoint_icd10
    |> cast(attrs, [:registry, :fg_endpoint_id, :icd10_id])
    |> validate_required([:registry, :fg_endpoint_id, :icd10_id])
    |> unique_constraint(:registry, name: :fg_endpoint_definition_icd10_registry)
  end
end
