# upset plots: upset_plots/interactive_plots/interactive_<ENDPOINT>.html
# info for detail tables: upset_plots/name_tables_json/name_table_<ENDPOINT>.html

# - we have list of endpoints with NO upset plots and name_table, get their reason, add info to DB
# - we have list of endpoints with upset plots and name_table, set info to DB, move upset plot, gen table
import Ecto.Query
require Logger
alias Risteys.FGEndpoint
alias Risteys.Repo
alias Risteys.KeyFigures

# --- CLI argument parser
[in_dir, dataset | _] = System.argv()

# raise an error if correct dataset info is not provided
# at the moment, upset plots and tables are only done from FinnGen data, so dataset needs to be FG
if dataset != "FG" do
  raise ArgumentError, message: "Dataset 'FG' need to be given as a second argument"
end

# --- Configuration
runlog_file = "error_log.csv"
upset_plots_dir = "interactive_plots"
upset_plots_prefix = "interactive_"
upset_plots_suffix = ".html"
tables_dir = "name_tables_json"
tables_prefix = "name_table_"
tables_suffix = ".json"

upset_plots_output = "priv/static/upset_plot/"
table_template = "template_upset_table.html.heex"
tables_output = "priv/static/table_case_counts/"

Logger.configure(level: :info)

# --- Gather input data
Logger.info("Gathering input data")

runlogs =
  in_dir
  |> Path.expand()
  |> Path.join(runlog_file)
  |> File.stream!()
  |> CSV.decode!(headers: true)
  |> Enum.reduce(%{}, fn row, acc ->
    %{
      "Endpoint" => endpoint,
      "Result" => result
    } = row

    Map.put_new(acc, endpoint, result)
  end)

upset_plots_path =
  in_dir
  |> Path.expand()
  |> Path.join(upset_plots_dir)

upset_plots =
  upset_plots_path
  |> File.ls!()
  |> Enum.filter(fn file ->
    String.starts_with?(file, upset_plots_prefix) and String.ends_with?(file, upset_plots_suffix)
  end)
  |> Enum.map(fn file ->
    endpoint =
      file
      |> String.replace_prefix(upset_plots_prefix, "")
      |> String.replace_suffix(upset_plots_suffix, "")

    path = Path.join(upset_plots_path, file)
    {endpoint, path}
  end)
  |> Enum.into(%{})

tables_path =
  in_dir
  |> Path.expand()
  |> Path.join(tables_dir)

tables =
  tables_path
  |> File.ls!()
  |> Enum.filter(fn file ->
    String.starts_with?(file, tables_prefix) and String.ends_with?(file, tables_suffix)
  end)
  |> Enum.map(fn file ->
    endpoint =
      file
      |> String.replace_prefix(tables_prefix, "")
      |> String.replace_suffix(tables_suffix, "")

    path = Path.join(tables_path, file)

    {endpoint, path}
  end)
  |> Enum.into(%{})

# --- Import upset plots
Logger.info("Adding upset plots as static files and setting status in DB")

Enum.each(upset_plots, fn {endpoint, upset_path} ->
  Logger.debug("Importing upset plot for #{endpoint}")
  # Copy upset plot file to Risteys
  out = Path.join(upset_plots_output, Path.basename(upset_path))
  File.cp!(upset_path, out)

  # Set upset plot status
  FGEndpoint.set_status!(endpoint, :upset_plot, "ok")
end)

# --- Generate and import tables
Logger.info("Generating upset tables, adding as static files and setting status in DB")

registries = %{
  "PRIM_OUT" => "Avohilmo: Primary healthcare outpatient",
  "INPAT" => "Inpatient Hilmo",
  "OUTPAT" => "Outpatient Hilmo",
  "DEATH" => "Cause of death",
  "OPER_IN" => "Operations in inpatient Hilmo",
  "OPER_OUT" => "Operations in outpatient Hilmo",
  "PURCH" => "KELA drug purchase",
  "REIMB" => "KELA drug reimbursment",
  "CANC" => "Cancer"
}

# get number of all individuals (total cases) for each endpoint
db_endpoints =
  Repo.all(
    from endp in FGEndpoint.Definition,
      join: key_fig in KeyFigures,
      on: endp.id == key_fig.fg_endpoint_id,
      where: endp.name in ^Map.keys(tables) and key_fig.dataset == ^dataset,
      select: {endp.name, key_fig.nindivs_all}
  )
  |> Enum.into(%{})

Enum.each(tables, fn {endpoint, table_path} ->
  Logger.debug("Generating and importing upset table for #{endpoint}")
  # Generate HTML file from JSON table
  rows =
    table_path
    |> File.read!()
    |> Jason.decode!()
    # Discard rows with N<5
    |> Enum.reject(fn %{"Frequency_people" => freq} -> freq == "<5" end)
    |> Enum.map(fn row ->
      %{
        "Source" => source,
        "Tag" => tag,
        "Frequency_people" => case_count
      } = row

      # Handle missing data
      name = Map.get(row, "Name", "unknown")

      case_count = String.to_integer(case_count)

      case_percentage =
        case Map.fetch(db_endpoints, endpoint) do
          :error -> nil
          {:ok, nil} -> nil
          {:ok, total_cases} -> case_count / total_cases * 100
        end

      source_long = Map.fetch!(registries, source)

      %{
        source_long: source_long,
        source_code: source,
        tag: tag,
        name: name,
        case_count: case_count,
        case_percentage: case_percentage
      }
    end)

  if not Enum.empty?(rows) do
    # Put HTML file into Risteys
    html = EEx.eval_file(table_template, endpoint_name: endpoint, table: rows)
    out = Path.join(tables_output, endpoint <> ".html")
    File.write!(out, html)

    # Set table status
    FGEndpoint.set_status!(endpoint, :upset_table, "ok")
  else
    Logger.warning("Discarding upset table for #{endpoint}: no rows left after filtering.")
  end
end)

# --- Handle endpoints without upset data
Logger.info("Setting status for endpoints in DB without upset plot or table")
all_db_endpoints = Repo.all(FGEndpoint.Definition)

for endpoint <- all_db_endpoints,
    endpoint.status_upset_plot != "ok" or endpoint.status_upset_table != "ok" do
  failure =
    case Map.fetch(runlogs, endpoint.name) do
      :error ->
        Logger.warning("#{endpoint.name} not found in run log file")
        "not run"

      {:ok, status} ->
        cond do
          status == "Endpoint set to omit" -> "omit"
          status =~ "Not enough data" or status =~ "sizes too small" -> "not enough data"
          status =~ "No data found" -> "no data"
          status =~ "pending unroll" -> "pending unroll"
          true -> "unknown"
        end
    end

  if endpoint.status_upset_plot != "ok" do
    FGEndpoint.set_status!(endpoint, :upset_plot, failure)
  end

  if endpoint.status_upset_table != "ok" do
    FGEndpoint.set_status!(endpoint, :upset_table, failure)
  end
end
