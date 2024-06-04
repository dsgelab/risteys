defmodule Risteys.LabTestStats.DistributionsLabValues do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_test_stats_distributions_lab_values" do
    field :omop_concept_dbid, :id
    field :distributions, {:array, :map}

    timestamps()
  end

  @doc false
  def changeset(distributions_lab_values, attrs) do
    distributions_lab_values
    |> cast(attrs, [:omop_concept_dbid, :distributions])
    |> validate_required([:omop_concept_dbid, :distributions])
    |> validate_change(:distributions, fn :distributions, distributions ->
      validate_distributions_npeople(distributions)
    end)
    |> unique_constraint([:omop_concept_dbid])
  end

  defp validate_distributions_npeople(distributions) do
    Enum.flat_map(
      distributions,
      &Risteys.LabTestStats.validate_npeople_green(
        :distributions,
        &1,
        ["bins", Access.all()],
        "npeople"
      )
    )
  end
end
