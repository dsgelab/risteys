defmodule Risteys.FGEndpoint.DefinitionICD9 do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fg_endpoint_definitions_icd9s" do
    field :registry, :string
    field :fg_endpoint_id, :id
    field :icd9_id, :id

    timestamps()
  end

  @doc false
  def changeset(fg_endpoint_icd9, attrs) do
    fg_endpoint_icd9
    |> cast(attrs, [:registry, :fg_endpoint_id, :icd9_id])
    |> validate_required([:registry, :fg_endpoint_id, :icd9_id])
    |> unique_constraint(:registry, name: :fg_endpoint_definition_icd9_registry)
  end
end
