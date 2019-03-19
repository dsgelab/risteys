defmodule Risteys.Phenocode do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:code, :string, []}
  schema "phenocodes" do
    field :cod_codes, {:array, :string}
    field :hd_codes, {:array, :string}
    field :longname, :string

    timestamps()
  end

  @doc false
  def changeset(phenocode, attrs) do
    phenocode
    |> cast(attrs, [:code, :longname, :hd_codes, :cod_codes])
    |> validate_required([:code, :longname, :hd_codes, :cod_codes])
  end
end
