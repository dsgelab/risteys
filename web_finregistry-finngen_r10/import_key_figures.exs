alias Risteys.{FGEndpoint.Definition, Repo, KeyFigures}
require Logger

Logger.configure(level: :info)
[filepath, dataset | _ ] = System.argv()

# raise an error if correct dataset info is not provided
if dataset != "FG" and dataset != "FR" and dataset != "FR_index" do
  raise ArgumentError, message: "Dataset need to be given as a second argument, either FG, FR or FR_index."
end

# helper function
defmodule Risteys.ImportKeyFigHelpers do
  def convert_to_correct_type(value, type \\ "float") do
    value = if value == "", do: nil, else: String.to_float(value)

    if !is_nil(value) and type == "int" do
      round(value)
    else
      value # otherwise float numbers would be lost
    end
  end
end

filepath
|> File.stream!()
|> CSV.decode!(headers: :true)
|> Enum.each(fn row ->
  %{
    "endpoint" => name,
    "nindivs_all" => nindivs_all,
    "nindivs_female" => nindivs_female,
    "nindivs_male" => nindivs_male,
    "median_age_all" => median_age_all,
    "median_age_female" => median_age_female,
    "median_age_male" => median_age_male,
    "prevalence_all" => prevalence_all,
    "prevalence_female" => prevalence_female,
    "prevalence_male" => prevalence_male
  } = row

  Logger.info("Handling data of #{name}")

  endpoint = Repo.get_by(Definition, name: name)

  case endpoint do
    nil ->
      Logger.warning("Endpoint #{name} not in the DB, skipping")
    endpoint ->
      key_figures =
        case Repo.get_by(KeyFigures, fg_endpoint_id: endpoint.id, dataset: dataset) do
          nil -> %KeyFigures{}
          existing -> existing
        end

        |> KeyFigures.changeset(%{
          fg_endpoint_id: endpoint.id,
          nindivs_all: Risteys.ImportKeyFigHelpers.convert_to_correct_type(nindivs_all, "int"),
          nindivs_female: Risteys.ImportKeyFigHelpers.convert_to_correct_type(nindivs_female, "int"),
          nindivs_male: Risteys.ImportKeyFigHelpers.convert_to_correct_type(nindivs_male, "int"),
          median_age_all: Risteys.ImportKeyFigHelpers.convert_to_correct_type(median_age_all),
          median_age_female: Risteys.ImportKeyFigHelpers.convert_to_correct_type(median_age_female),
          median_age_male: Risteys.ImportKeyFigHelpers.convert_to_correct_type(median_age_male),
          prevalence_all: Risteys.ImportKeyFigHelpers.convert_to_correct_type(prevalence_all),
          prevalence_female: Risteys.ImportKeyFigHelpers.convert_to_correct_type(prevalence_female),
          prevalence_male: Risteys.ImportKeyFigHelpers.convert_to_correct_type(prevalence_male),
          dataset: dataset
        })
        |> Repo.insert_or_update()

    case key_figures do
      {:ok, _} ->
        Logger.info("Insert ok")
      {:error, changeset} ->
        Logger.warn(inspect(changeset))
    end
  end
end)
