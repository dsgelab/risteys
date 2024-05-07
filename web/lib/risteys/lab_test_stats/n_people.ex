defmodule Risteys.LabTestStats.NPeople do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_test_stats_npeople" do
    field :count, :integer
    field :sex, :string

    # Not an OMOP concept ID, but a database ID
    field :omop_concept_dbid, :id

    timestamps()
  end

  @doc false
  def changeset(stats_npeople, attrs) do
    stats_npeople
    |> cast(attrs, [:sex, :count, :omop_concept_dbid])
    |> validate_required([:sex, :count, :omop_concept_dbid])
    |> validate_number(:count, greater_than_or_equal_to: 5)
    |> validate_inclusion(:sex, ["male", "female"])
    |> unique_constraint([:omop_concept_dbid, :sex], name: :uidx_lab_test_stats_npeople)
  end
end
