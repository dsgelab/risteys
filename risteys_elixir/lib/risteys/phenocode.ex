defmodule Risteys.Phenocode do
  use Ecto.Schema
  import Ecto.Changeset

  schema "phenocodes" do
    field :cod_codes, {:array, :string}
    field :code, :string
    field :hd_codes, {:array, :string}
    field :longname, :string

    timestamps()

    has_many :health_events, Risteys.HealthEvent
  end

  @doc false
  def changeset(phenocode, attrs) do
    phenocode
    |> cast(attrs, [:code, :longname, :hd_codes, :cod_codes])
    |> validate_required([:code, :longname, :hd_codes, :cod_codes])
    |> unique_constraint(:code)
  end
end
