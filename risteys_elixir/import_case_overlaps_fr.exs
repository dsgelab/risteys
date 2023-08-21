# Import FinRegistry case overlap count and percentage for endpoint pars

# Usage: mix run import_case_overlaps_fr.exs <case_overlaps_csv_file>

# where <case_overlaps_csv_file> is a csv file witht the following columns
# - endpoint1
# - endpoint2
# - case_overlap
# - jaccard_index

alias Risteys.{Repo, FGEndpoint.Definition, FGEndpoint.CaseOverlapsFR}
require Logger

Logger.configure(level: :info)
[filepath | _] = System.argv()

filepath
|> File.stream!()
|> CSV.decode!(headers: :true)
|> Enum.each(fn row ->
  %{
    "endpoint1" => endpoint_a_name,
    "endpoint2" => endpoint_b_name,
    "case_overlap" => case_overlap_N,
    "jaccard_index" => jaccard_index
  } = row

  Logger.info("Handling data of endpoint pair #{endpoint_a_name} – #{endpoint_b_name}")

  endpoint_a = Repo.get_by(Definition, name: endpoint_a_name)
  endpoint_b = Repo.get_by(Definition, name: endpoint_b_name)

  case {endpoint_a, endpoint_b} do
    {nil, _} -> Logger.warning("Endpoint #{endpoint_a_name} not in DB, skipping.")
    {_, nil} -> Logger.warning("Endpoint #{endpoint_b_name} not in DB, skipping.")

    {endpoint_a, endpoint_b} ->
      case_overlap =
        case Repo.get_by(CaseOverlapsFR, fg_endpoint_a_id: endpoint_a.id, fg_endpoint_b_id: endpoint_b.id) do
          nil -> %CaseOverlapsFR{}
          existing -> existing
        end

      |> CaseOverlapsFR.changeset(%{
        fg_endpoint_a_id: endpoint_a.id,
        fg_endpoint_b_id: endpoint_b.id,
        case_overlap_N: String.to_integer(case_overlap_N), # Missing 'case_overlap_N' or 'jaccard_index' value will crash the script because that would mean there is a mistake in the input data
        case_overlap_percent: (Float.parse(jaccard_index) |> elem(0)) *100 # Float.parse need to be used to enable parsing string without a decimal point, like "6e-05"
      })
      |> Repo.insert_or_update()

      case case_overlap do
        {:ok, _} ->
            Logger.info("insert ok")
        {:error, changeset} ->
          Logger.warning(inspect(changeset))
      end
  end
end)
