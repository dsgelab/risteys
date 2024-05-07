defmodule Risteys.OMOP.LOINCRelationship do
  use Ecto.Schema
  import Ecto.Changeset

  schema "omop_loinc_relationships" do
    # Not the OMOP Concept ID, but the DB assigned ID
    field :lab_test_id, :id

    # Not the OMOP Concept ID, but the DB assigned ID
    field :loinc_component_id, :id

    timestamps()
  end

  @doc false
  def changeset(loinc_relationship, attrs) do
    loinc_relationship
    |> cast(attrs, [:lab_test_id, :loinc_component_id])
    |> validate_required([:lab_test_id, :loinc_component_id])
    |> unique_constraint([:lab_test_id, :loinc_component_id],
      name: :uidx_omop_loinc_relationships
    )
  end
end
