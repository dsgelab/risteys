defmodule Risteys.Genomics.Gene do
  use Ecto.Schema
  import Ecto.Changeset

  schema "genes" do
    field :chromosome, :string
    field :ensid, :string
    field :name, :string
    field :start, :integer
    field :stop, :integer

    timestamps()
  end

  @doc false
  def changeset(gene, attrs) do
    gene
    |> cast(attrs, [:ensid, :name, :chromosome, :start, :stop])
    |> validate_required([:ensid, :name, :chromosome, :start, :stop])
    |> unique_constraint(:ensid)
  end
end
