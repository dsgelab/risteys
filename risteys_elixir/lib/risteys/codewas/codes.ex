defmodule Risteys.CodeWAS.Codes do
  use Ecto.Schema
  import Ecto.Changeset

  schema "codewas_codes" do
    field :code, :string
    field :description, :string
    field :vocabulary, :string
    field :odds_ratio, :float
    field :nlog10p, :float
    field :n_matched_cases, :integer
    field :n_matched_controls, :integer
    field :fg_endpoint_id, :id

    timestamps()
  end

  @doc false
  def changeset(codewas_codes, attrs) do
    codewas_codes
    |> cast(attrs, [:code, :vocabulary, :description, :odds_ratio, :nlog10p, :n_matched_cases, :n_matched_controls, :fg_endpoint_id])
    |> validate_required([:code, :vocabulary, :description, :odds_ratio, :nlog10p, :fg_endpoint_id])
    |> validate_change(:n_matched_cases, &Risteys.Utils.is_green/2)
    |> validate_change(:n_matched_controls, &Risteys.Utils.is_green/2)
    |> unique_constraint(:codewas_codes)
  end
end
