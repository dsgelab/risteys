defmodule Risteys.LabTestStats.DatasetMetadata do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_test_stats_dataset_metadata" do
    field :npeople_alive, :integer

    timestamps()
  end

  @doc false
  def changeset(dataset_metadata, attrs) do
    dataset_metadata
    |> cast(attrs, [:npeople_alive])
    |> validate_required([:npeople_alive])
  end
end
