defmodule Risteys.LabTestStats.DistributionYearOfBirth do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lab_test_stats_distribution_year_of_birth" do
    field :omop_concept_dbid, :id

    # Each OMOP concept has a distribution associated with it, with this shape:
    # distribution =
    #   %{
    #     bins: [
    #       %{"range" => "bin range" Str, "npeople" => N Int},
    #       ...
    #     ],
    #     breaks: [year Int, year Int, ... year Int]
    #
    #   }
    field :distribution, :map

    timestamps()
  end

  @doc false
  def changeset(distribution_year_of_birth, attrs) do
    distribution_year_of_birth
    |> cast(attrs, [:omop_concept_dbid, :distribution])
    |> validate_required([:omop_concept_dbid, :distribution])
    |> validate_change(:distribution, fn :distribution, dist ->
      Risteys.LabTestStats.validate_npeople_green(
        :distribution,
        dist,
        ["bins", Access.all()],
        "npeople"
      )
    end)
    |> unique_constraint([:omop_concept_dbid])
  end
end
