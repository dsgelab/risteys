# Import FinnGen genetic correlation data

# Usage:
# mix run import_genetic_correlations.exs <genetic-correlations-tsv-file>

# where <genetic-correlations-tsv-file> is tsv file of FinnGen genetic correlation data for endpoint pairs,
# finngen_R10_FIN.ldsc.summary.tsv for R10,
# with the following columns:

# p1	- endpoint a, string
# p2	- endpoint b, string
# rg	– Genetic correlation, float
# se	– Standard error, float
# p – p-value, float
# CONVERGED – A flag showing whether the LDSC logs have or have not raised a potential issue, string

alias Risteys.{FGEndpoint, Repo}
alias FGEndpoint.GeneticCorrelation
import Ecto.Query
require Logger

Logger.configure(level: :info)
[gen_corr_filepath | _] = System.argv()

endpoints = Repo.all(from endpoint in FGEndpoint.Definition, select: endpoint.name) |> MapSet.new()

gen_corr_filepath
|> File.stream!()
|> CSV.decode!(separator: ?\t, headers: true)
|> Stream.filter(fn %{"CONVERGED" => converged, "p1" => endpoint_a_name, "p2" => endpoint_b_name} ->
  # import only results where CONVERGED == "True" to keep ony reliable results
  if converged != "True" do
    Logger.debug("LDSC convergence issue for endpoint pair #{endpoint_a_name} – #{endpoint_b_name}")
  end

  converged == "True"
end)
|> Stream.filter(fn %{"p1" => endpoint_a_name, "p2" => endpoint_b_name} ->
  # Take only endpoint pairs where both endpoints are found from the DB
  # and endpoints are not the same endpoint
  endp_a_in_endpoints = MapSet.member?(endpoints, endpoint_a_name)

  if not endp_a_in_endpoints do
    Logger.warning("Endpoint A, #{endpoint_a_name}, not found in endpoints")
  end

  endp_b_in_endpoints = MapSet.member?(endpoints, endpoint_b_name)

  if not endp_b_in_endpoints do
    Logger.warning("Endpoint B #{endpoint_b_name} not found in endpoints")
  end

  not_same_endpoint = endpoint_a_name != endpoint_b_name

  endp_a_in_endpoints and endp_b_in_endpoints and not_same_endpoint
end)
|> Stream.filter(fn %{"rg" => rg, "p1" => endpoint_a_name, "p2" => endpoint_b_name} ->
  #filter out rows where rg is missing
  if rg == "NA" do
    Logger.warning("Missing rg value for endpoint pair #{endpoint_a_name} – #{endpoint_b_name}")
  end

  rg != "NA"
end)
|> Stream.with_index()
|> Enum.each(fn {%{
  # Take only needed columns
  "p1" => endpoint_a_name,
  "p2" => endpoint_b_name,
  "rg" => rg,
  "se" => se,
  "p" => pvalue
  }, idx} ->

  Logger.debug("Processing pair: #{endpoint_a_name} & #{endpoint_b_name}")

  if Integer.mod(idx, 1000) == 0 do
    Logger.info("At line #{idx}")
  end

  # Get the endpoint IDs for endpoint_a and endpoint_b
  endpoint_a = Repo.get_by!(FGEndpoint.Definition, name: endpoint_a_name)
  endpoint_b = Repo.get_by!(FGEndpoint.Definition, name: endpoint_b_name)

  # Round rg to be between -1 and 1
  rg = String.to_float(rg)
  rg = if rg > 1, do: 1.0, else: rg
  rg = if rg < -1, do: -1.0, else: rg

  gen_corr =
    case Repo.get_by(GeneticCorrelation,
          fg_endpoint_a_id: endpoint_a.id,
          fg_endpoint_b_id: endpoint_b.id,
          ) do
      nil -> %GeneticCorrelation{}
      existing -> existing
    end
    |> GeneticCorrelation.changeset(%{
      fg_endpoint_a_id: endpoint_a.id,
      fg_endpoint_b_id: endpoint_b.id,
      rg: rg,
      se: String.to_float(se),
      pvalue: String.to_float(pvalue),
    })
    |> Repo.insert_or_update()

  case gen_corr do
    {:ok, _} ->
      Logger.debug("insert/update ok")

    {:error, changeset} ->
      Logger.warning(inspect(changeset))
  end

  # Import analysis results in both directions because for genetic correlation a --> b is same as b --> a,
  # and results need to be saved in both directions for function to calculate rg extremity works correctly
  gen_corr_opp_dir =
    case Repo.get_by(GeneticCorrelation,
          fg_endpoint_a_id: endpoint_b.id,
          fg_endpoint_b_id: endpoint_a.id,
          ) do
      nil -> %GeneticCorrelation{}
      existing -> existing
    end
    |> GeneticCorrelation.changeset(%{
      fg_endpoint_a_id: endpoint_b.id,
      fg_endpoint_b_id: endpoint_a.id,
      rg: rg,
      se: String.to_float(se),
      pvalue: String.to_float(pvalue),
    })
    |> Repo.insert_or_update()

  case gen_corr_opp_dir do
    {:ok, _} ->
      Logger.debug("insert/update ok")

    {:error, changeset} ->
      Logger.warning(inspect(changeset))
  end

end)
Logger.info("Import done.")
