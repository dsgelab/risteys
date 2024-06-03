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
    |> validate_change(:distribution, &check_npeople_green/2)
    |> unique_constraint([:omop_concept_dbid])
  end

  defp check_npeople_green(:distribution, %{"bins" => bins}) do
    bins
    |> Enum.map(&check_bin/1)
    |> Enum.reject(&is_nil/1)
  end

  defp check_bin(bin) do
    case Map.get(bin, "npeople") do
      nil ->
        {:distribution, "Bin is missing the \"npeople\" key, bin=#{inspect(bin)}"}

      npeople when is_integer(npeople) and npeople < 5 ->
        {:distribution, "Bin has wrong \"npeople\" value, expected an integer >= 5, instead got: #{inspect(npeople)}"}

      _ ->
        nil
    end
  end

end
