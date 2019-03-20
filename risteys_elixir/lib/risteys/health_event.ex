defmodule Risteys.HealthEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "health_events" do
    field :age, :float
    field :dateevent, :date
    field :death, :boolean, default: false
    field :eid, :integer
    field :sex, :integer

    timestamps()

    belongs_to :phenocode, Risteys.Phenocode
  end

  @doc false
  def changeset(health_event, attrs) do
    health_event
    |> cast(attrs, [:eid, :sex, :death, :dateevent, :age])
    |> validate_required([:eid, :sex, :death, :dateevent, :age])
    |> validate_inclusion(:sex, [1, 2])
    |> validate_number(:age, greater_than: 0)
  end
end
