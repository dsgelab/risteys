# Import parameters for mortality table and interactively computing mortality
#
# Usage: mix run <mortality-params-csv-file>
#
# where <mortality-params-csv-file> is a csv file witht the following columns
# - covariate
# - coef
# - ci95_lower
# - ci95_upper
# - p_value
# - endpoint
# - mean
# - sex

alias Risteys.{Repo, FGEndpoint.Definition, MortalityParams}
require Logger

Logger.configure(level: :info)
[filepath | _] = System.argv()

filepath
|> File.stream!()
|> CSV.decode!(headers: :true)
|> Enum.each(fn row ->
  %{
    "endpoint" => name,
    "covariate" => covariate,
    "coef" => coef,
    "ci95_lower" => ci95_lower,
    "ci95_upper" => ci95_upper,
    "p_value" => p_value,
    "mean" => mean,
    "sex" => sex
  } = row

  Logger.info("Handling data of #{name}")

  endpoint = Repo.get_by(Definition, name: name)

  case endpoint do
    nil ->
      Logger.warning("Enpoint #{name} not in DB, skipping.")

    endpoint ->
      params =
        case Repo.get_by(MortalityParams, fg_endpoint_id: endpoint.id, covariate: covariate, sex: sex) do
          nil -> %MortalityParams{}
          existing -> existing
        end

        |> MortalityParams.changeset(%{
          fg_endpoint_id: endpoint.id,
          covariate: covariate,
          coef: String.to_float(coef),
          ci95_lower: String.to_float(ci95_lower),
          ci95_upper: String.to_float(ci95_upper),
          p_value: String.to_float(p_value),
          mean: String.to_float(mean),
          sex: sex
        })
        |> Repo.insert_or_update()

      case params do
        {:ok, _} ->
          Logger.info("Insert ok")
        {:error, changeset} ->
          Logger.warn(inspect(changeset))
      end
  end
end)
