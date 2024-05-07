# Import baseline cumulative hazards for interactively computing mortality
#
# Usage: mix run import_interactive_mortaity_baseline.exs <mortaity-baseline-csv-file>
#
# where <mortaity-baseline-csv-file> is a csv file witht the following columns
# - age
# - baseline_cumulative_hazard
# - endpoint
# - sex


alias Risteys.{Repo, FGEndpoint.Definition, MortalityBaseline}
require Logger

Logger.configure(level: :info)
[filepath | _] = System.argv()

filepath
|> File.stream!()
|> CSV.decode!(headers: :true)
|> Enum.each(fn row ->
  %{
    "endpoint" => name,
    "age" => age,
    "baseline_cumulative_hazard" => baseline_cumulative_hazard,
    "sex" => sex
  } = row

  Logger.info("Handling data of #{name}")

  endpoint = Repo.get_by(Definition, name: name)

  case endpoint do
    nil ->
      Logger.warning("Enpoint #{name} not in DB, skipping.")

    endpoint ->
      baseline =
        case Repo.get_by(MortalityBaseline, fg_endpoint_id: endpoint.id, age: age, sex: sex) do
          nil -> %MortalityBaseline{}
          existing -> existing
        end

        |> MortalityBaseline.changeset(%{
          fg_endpoint_id: endpoint.id,
          age: String.to_float(age),
          baseline_cumulative_hazard: String.to_float(baseline_cumulative_hazard),
          sex: sex
        })
        |> Repo.insert_or_update()

      case baseline do
        {:ok, _} ->
          Logger.info("Insert ok")
        {:error, changeset} ->
          Logger.warning(inspect(changeset))
      end
  end
end)
