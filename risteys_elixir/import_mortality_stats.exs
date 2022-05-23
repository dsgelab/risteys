alias Risteys.{FGEndpoint, Repo, MortalityStats}
import Ecto.Query
require Logger

Logger.configure(level: :info)
[stats_filepath | _] = System.argv()

endpoints = Repo.all(from endpoint in FGEndpoint.Definition, select: endpoint.name) |> MapSet.new()

stats_filepath
|> File.stream!()
|> CSV.decode!(headers: true)
|> Stream.filter(fn %{"endpoint" => endpoint} ->
  is_in_endpoints = MapSet.member?(endpoints, endpoint)

  if not is_in_endpoints do
    Logger.warn("Endpoint #{endpoint} not found in DB, skipping.")
  end

  is_in_endpoints
end)
|> Enum.each(fn %{
                  "endpoint" => endpoint,
                  "lag_hr" => lag_hr,
                  "endpoint_hr" => hr,
                  "endpoint_ci_lower" => hr_ci_min,
                  "endpoint_ci_upper" => hr_ci_max,
                  "endpoint_pval" => pvalue,
                  "nindivs_prior_later" => nindivs,
                  "absolute_risk" => abs_risk
                } ->
  lag_hr =
    if lag_hr == "" do
      0
    else
      lag_hr |> String.to_integer()
    end

  endpoint = Repo.get_by!(FGEndpoint.Definition, name: endpoint)

  stat =
    case Repo.get_by(MortalityStats, fg_endpoint_id: endpoint.id, lagged_hr_cut_year: lag_hr) do
      nil -> %MortalityStats{}
      existing -> existing
    end
    |> MortalityStats.changeset(%{
      fg_endpoint_id: endpoint.id,
      lagged_hr_cut_year: lag_hr,
      hr: String.to_float(hr),
      hr_ci_min: String.to_float(hr_ci_min),
      hr_ci_max: String.to_float(hr_ci_max),
      pvalue: String.to_float(pvalue),
      n_individuals: String.to_integer(nindivs),
      absolute_risk: String.to_float(abs_risk)
    })
    |> Repo.insert_or_update()

  case stat do
    {:ok, _} ->
      Logger.debug("insert/update ok")

    {:error, changeset} ->
      Logger.warn(inspect(changeset))
  end
end)
