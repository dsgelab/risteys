# Import counts of individuals that have a given endpoint (exposed)
# and count of individuals that have died among those who have the given endpoint (exposed_cases)

# Usage: mix run import_mortality_counts.exs <mortality_counts_csv_file>

# where <mortality_counts_csv_file> is a csv file witht the following columns
# - endpoint
# - exposed
# - exposed_cases
# - sex

alias Risteys.{Repo, FGEndpoint.Definition, MortalityCounts}
require Logger

Logger.configure(level: :info)
[filepath | _] = System.argv()

filepath
|> File.stream!()
|> CSV.decode!(headers: :true)
|> Enum.each(fn row ->
  %{
    "endpoint" => name,
    "exposed" => exposed,
    "exposed_cases" => exposed_cases,
    "sex" => sex
  } = row

  Logger.info("Handling data of #{name}")

  endpoint = Repo.get_by(Definition, name: name)

  case endpoint do
    nil -> Logger.warning("Enpoint #{name} not in DB, skipping.")

    endpoint ->
      counts =
        case Repo.get_by(MortalityCounts, fg_endpoint_id: endpoint.id, sex: sex) do
          nil -> %MortalityCounts{}
          existing -> existing
        end

      |> MortalityCounts.changeset(%{
        fg_endpoint_id: endpoint.id,
        exposed: String.to_integer(exposed),
        exposed_cases: String.to_integer(exposed_cases),
        sex: sex
      })
      |> Repo.insert_or_update()

      case counts do
        {:ok, _} ->
            Logger.info("insert ok")
        {:error, changeset} ->
          Logger.warn(inspect(changeset))
      end
  end
end)
