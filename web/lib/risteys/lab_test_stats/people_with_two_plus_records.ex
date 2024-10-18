defmodule Risteys.LabTestStats.PeopleWithTwoPlusRecords do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_test_stats_people_with_two_plus_records" do
    field :percent_people, :float
    field :npeople, :integer
    field :omop_concept_dbid, :id

    timestamps()
  end

  @doc false
  def changeset(people_with_two_plus_records, attrs) do
    people_with_two_plus_records
    |> cast(attrs, [:percent_people, :npeople, :omop_concept_dbid])
    |> validate_required([:percent_people, :npeople, :omop_concept_dbid])
    |> validate_number(:percent_people, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:npeople, greater_than_or_equal_to: 5)
    |> unique_constraint([:omop_concept_dbid])
  end
end
