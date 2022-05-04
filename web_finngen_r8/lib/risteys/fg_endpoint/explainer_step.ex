defmodule Risteys.FGEndpoint.ExplainerStep do
  use Ecto.Schema
  import Ecto.Changeset

  schema "endp_explainer_step" do
    field :phenocode_id, :id

    field :step, :string
    # "nil" will indicate individual-level data: 1, 2, 3, or 4.
    field :nindivs, :integer

    timestamps()
  end

  @doc false
  def changeset(explainer_step, attrs) do
    explainer_step
    |> cast(attrs, [:phenocode_id, :step, :nindivs])
    # :nindivs can be "nil"
    |> validate_required([:phenocode_id, :step])

    # Making sure no individual-level data comes in
    |> validate_number(:nindivs, greater_than_or_equal_to: 0)
    |> validate_exclusion(:nindivs, 1..4)
    |> unique_constraint(:phenocode_id, name: :phenocode_step)
  end
end
