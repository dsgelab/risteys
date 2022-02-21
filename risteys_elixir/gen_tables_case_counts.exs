# Generate HTML tables of case counts by registry codes
#
# Usage:
#   mix run gen_tables_case_counts.exs <dir-input-json> <dir-output-html>
#
# where:
# <dir-input-json> is a directory containing JSON files (1 per endpoint) of case counts by registry codes.
# <dir-output-html> is a directory where the resulting HTML files will be

alias Risteys.{Repo, Phenocode, StatsSex}
require Logger

Logger.configure(level: :info)

[in_dir, out_dir | _] = System.argv()

sources = %{
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

# Get all JSON files
in_dir
|> Path.expand()
|> File.ls!()
|> Stream.filter(&String.ends_with?(&1, ".json"))

# Get endpoints info
|> Stream.map(fn filename ->
  name =
    filename
    |> Path.basename(".json")
    |> String.replace_prefix("name_table_", "")

  %{
    filename: filename,
    filepath: Path.join(in_dir, filename),
    ecto: Repo.get_by(Phenocode, name: name)
  }
end)

# Construct intermediate data structures
|> Stream.map(fn endpoint_info ->
  table =
    endpoint_info.filepath
    |> File.read!()
    |> Jason.decode!()
    # Discard rows with N<5
    |> Enum.reject(fn row -> row["Frequency_people"] == "<5" end)
    |> Enum.map(fn row ->
      count = row["Frequency_people"]

      case_count = String.to_integer(count)
      source_text = sources[row["Source"]]

      %{
        tag: row["Tag"],
        name: row["Name"],
        source_code: row["Source"],
        source_text: source_text,
        case_count: case_count
      }
    end)

  sex_any = 0
  stats = Repo.get_by(StatsSex, sex: sex_any, phenocode_id: endpoint_info.ecto.id)
  # some endpoints don't have any stats, e.g. due to very low N
  total_cases =
    if is_nil(stats) do
      nil
    else
      stats.n_individuals
    end

  table =
    Enum.map(table, fn row ->
      case_percentage =
        if not is_nil(total_cases) do
          row.case_count / total_cases * 100
        else
          nil
        end

      Map.put_new(row, :case_percentage, case_percentage)
    end)

  %{endpoint: endpoint_info.ecto, table: table}
end)

# Transform to HTML with template
|> Stream.map(fn %{endpoint: endpoint, table: table} ->
  %{
    endpoint: endpoint.name,
    html: EEx.eval_file("template_table.html.heex", endpoint: endpoint, table: table)
  }
end)

# Output HTML files
|> Enum.map(fn %{endpoint: endpoint, html: html} ->
  filename = endpoint <> ".html"

  out_path =
    out_dir
    |> Path.expand()
    |> Path.join(filename)

  File.write!(out_path, html)
end)
