# Import endpoint definition intermediate counts to the DB
#
# Usage: mix run import_intermediate_counts.exs <counts_filepath> <dataset>
# where
# <counts_filepath> is path to intermediate counts input file, that is csv file with the following columns:
# ENDPOINT,SOURCE,N(all),N(-sex),N(-conditions),N(-regex),N(-pre_conditions/mainonly/mode/icdver/reimb_icd),N(-nevt),N(pass+include_unique)
#
# <dataset> is either "FR" for FinRegistry counts or "FG" for FinnGen counts

alias Risteys.FGEndpoint

require Logger

Logger.configure(level: :info)
[counts_filepath, dataset | _] = System.argv()

# raise an error if correct dataset info is not provided
if dataset != "FG" and dataset != "FR" do
  raise ArgumentError, message: "Dataset need to be given as a second argument, either FG or FR."
end

# Map: name -> id
endpoints = FGEndpoint.list_endpoints_ids()

counts_filepath
|> File.stream!()
|> CSV.decode!(separator: ?\t, headers: true)

# We are not interested in registry specific counts
|> Stream.filter(fn %{"SOURCE" => source} -> source == "ALL" end)

# Process only the necessary data
|> Stream.map(fn row ->
  endpoint_name = row["ENDPOINT"]
  endpoint_id = endpoints[endpoint_name]

  %{
    "N(all)" => nall,
    "N(-sex)" => nsex,
    "N(-conditions)" => nconditions,
    "N(-pre_conditions/mainonly/mode/regex_icdver/reimb_icd)" => nmulti,
    "N(-nevt)" => nevt,
    "N(pass+include_unique)" => nend
  } = row

  # Ordering the steps, so we can later check for individual-level data that
  # can be deduced between 2 steps.
  steps =
    [
      {"all", nall},
      {"sex_rule", nsex},
      {"conditions", nconditions},
      {"multi", nmulti},
      {"min_number_events", nevt},
      {"includes", nend}
    ]
    |> Enum.map(fn {step, count} ->
      val = if count == "NA", do: nil, else: String.to_integer(count)
      {step, val}
    end)

  {endpoint_id, endpoint_name, steps}
end)

# Abort if any single value has individual-level data
|> Stream.map(fn proc_row ->
  {_endpoint_id, endpoint_name, steps} = proc_row

  has_indiv_data =
    steps
    |> Enum.any?(fn {_, n} -> n in 1..4 end)

  if has_indiv_data do
    Logger.error("Individual-level data detected (single value) for #{endpoint_name}, aborting.")
    exit(:has_indiv_data)
  end

  proc_row
end)

# Checking for individual-level data between 2 consecutive steps
|> Stream.map(fn proc_row ->
  {_endpoint_id, endpoint_name, steps} = proc_row

  has_indiv_level =
    steps
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.any?(fn [{_, a}, {_, b}] ->
      needs_check = not is_nil(a) and not is_nil(b)
      needs_check and abs(a - b) in 1..4
    end)

  if has_indiv_level do
    Logger.error("Individual-level data detected (diff) for: #{endpoint_name}, aborting.")
    exit(:has_indiv_data)
  end

  proc_row
end)

# Discard data where we don't have the endpoint in Risteys
|> Stream.reject(fn {endpoint_id, endpoint_name, _steps} ->
  is_not_found = is_nil(endpoint_id)

  if is_not_found do
    Logger.warn("Endpoint not found, skipping: #{endpoint_name}")
  end

  is_not_found
end)

# Finally, import data into the database
|> Enum.each(fn {endpoint_id, endpoint_name, steps} ->
  for {step, count} <- steps do
    # Check for individual-level data is done there
    upsert =
      FGEndpoint.upsert_explainer_step(%{
        fg_endpoint_id: endpoint_id,
        step: step,
        nindivs: count,
        dataset: dataset
      })

    case upsert do
      {:ok, _} ->
        Logger.debug("insert/update of for #{endpoint_name}")

      {:error, changeset} ->
        Logger.warn(inspect(changeset))
    end
  end
end)
