defmodule Risteys.CodeWAS.Codes do
  use Ecto.Schema
  import Ecto.Changeset

  schema "codewas_codes" do
    field :code, :string
    field :description, :string
    field :vocabulary, :string
    field :odds_ratio, :float
    field :nlog10p, :float
    field :n_matched_cases, :integer     # nil represents N < 5
    field :n_matched_controls, :integer  # nil represents N < 5
    field :fg_endpoint_id, :id

    timestamps()
  end

  @doc false
  def changeset(codewas_codes, attrs) do
    codewas_codes
    |> cast(attrs, [:code, :vocabulary, :description, :odds_ratio, :nlog10p, :n_matched_cases, :n_matched_controls, :fg_endpoint_id])
    |> validate_required([:code, :vocabulary, :description, :odds_ratio, :nlog10p, :fg_endpoint_id])
    |> validate_number(:n_matched_cases, greater_than_or_equal_to: 5)
    |> validate_number(:n_matched_controls, greater_than_or_equal_to: 5)
    |> unique_constraint(:codewas_codes)
  end
end
