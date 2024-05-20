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
    |> parse_integers_in_bins()
    |> validate_change(:distributions, &check_npeople/2)
    |> unique_constraint([:omop_concept_dbid])
  end

  defp parse_integers_in_bins(changeset) do
    %{
      changes:
        %{
          distributions: distributions
        } = changes
    } = changeset

    new_distributions =
      for dist <- distributions do
        new_bins =
          for %{"npeople" => npeople, "nrecords" => nrecords} = bin <- dist["bins"] do
            npeople =
              case is_binary(npeople) do
                true -> String.to_integer(npeople)
                false -> npeople
              end

            nrecords =
              case is_binary(nrecords) do
                true -> String.to_integer(nrecords)
                false -> nrecords
              end

            %{bin | "npeople" => npeople, "nrecords" => nrecords}
          end

        %{dist | "bins" => new_bins}
      end

    %{
      changeset
      | changes: %{
          changes
          | distributions: new_distributions
        }
    }
  end

  defp check_npeople(:distributions, distributions) do
    distributions
    |> Enum.map(fn %{"measurement_unit" => measurement_unit, "bins" => bins} ->
      check_bins(bins, measurement_unit, :distributions)
    end)
    |> List.flatten()
  end

  defp check_bins(bins, measurement_unit, field) do
    Enum.map(bins, &check_one_bin(&1, measurement_unit, field))
  end

  defp check_one_bin(bin, measurement_unit, field) do
    errors =
      [
        "bin",
        "nrecords",
        "npeople"
      ]
      |> Enum.map(fn required_key ->
        if not Map.has_key?(bin, required_key) do
          {field,
           "Bin doesn't have the required key \"#{required_key}\", bin=#{inspect(bin)}, measurement_unit=#{measurement_unit}"}
        end
      end)
      |> Enum.reject(&is_nil/1)

    case Map.get(bin, "npeople") do
      nil ->
        errors

      npeople when is_integer(npeople) and npeople >= 5 ->
        errors

      npeople ->
        [{field, "Bin has less than 5 people, got: #{npeople}"} | errors]
    end
  end
end
