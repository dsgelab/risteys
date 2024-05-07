defmodule Risteys.OMOP.Concept do
  use Ecto.Schema
  import Ecto.Changeset

  schema "omop_concepts" do
    field :concept_id, :string
    field :concept_name, :string

    timestamps()
  end

  @doc false
  def changeset(concept, attrs) do
    concept
    |> cast(attrs, [:concept_id, :concept_name])
    |> validate_required([:concept_id, :concept_name])
    |> unique_constraint([:concept_id], name: :uidx_omop_concepts)
  end
end
