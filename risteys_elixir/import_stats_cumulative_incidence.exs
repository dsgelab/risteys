alias Risteys.Repo
alias Risteys.FGEndpoint
import Ecto.Query
require Logger

Logger.configure(level: :info)
[stats_filepath | _] = System.argv()

Logger.info("Getting existing endpoint IDs")
# Map of endpoint name -> id
endpoints =
  Repo.all(from endpoint in FGEndpoint.Definition, select: %{name: endpoint.name, id: endpoint.id})
  |> Enum.reduce(%{}, fn %{name: name, id: id}, acc ->
    Map.put_new(acc, name, id)
  end)

# Delete all previous data for the endpoints that will be inserted
# from the input.
Logger.info("Reading input file to delete records to be updated")

to_delete =
  stats_filepath
  |> File.stream!()
  |> CSV.decode!(headers: true)
  |> Enum.reduce(MapSet.new(), fn %{"endpoint" => name}, acc ->
    case Map.get(endpoints, name) do
      nil -> acc
      endpoint_id -> MapSet.put(acc, endpoint_id)
    end
  end)
  |> MapSet.to_list()

{n_deleted, _} = FGEndpoint.delete_cumulative_incidence(to_delete)

Logger.info("Preparing insert/update, number of records deleted: #{n_deleted}.")

Logger.info("Inserting new data")

stats_filepath
|> File.stream!()
|> CSV.decode!(headers: true)
|> Enum.each(fn row ->
  %{
    "endpoint" => name,
    "age" => age,
    "cumulinc" => value,
    "sex" => sex
  } = row

  Logger.debug("Handling data: #{name} - #{sex} - #{age}")

  endpoint_id = Map.get(endpoints, name)
  age = String.to_float(age)
  value = String.to_float(value)

  if is_nil(endpoint_id) do
    Logger.warning("Endpoint #{name} not found in DB, skipping.")
  else
    attrs = %{
      fg_endpoint_id: endpoint_id,
      age: age,
      value: value,
      sex: sex
    }

    case FGEndpoint.create_cumulative_incidence(attrs) do
      {:ok, _struct} -> Logger.debug("Insert ok for #{name} at age #{age}")
      {:error, changeset} -> IO.inspect(changeset)
    end
  end
end)
