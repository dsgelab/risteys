alias Risteys.FGEndpoint

require Logger

Logger.configure(level: :info)
[counts_filepath | _] = System.argv()

# Map: name -> id
endpoints = FGEndpoint.list_endpoints_ids()

counts_filepath
|> File.stream!()
|> CSV.decode!(headers: true)

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
    "N(-regex)" => nregex,
    "N(-pre_conditions/mainonly/mode/icdver/reimb_icd)" => nmulti,
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
      {"filter_registries", nregex},
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
        phenocode_id: endpoint_id,
        step: step,
        nindivs: count
      })

    case upsert do
      {:ok, _} ->
        Logger.debug("insert/update of for #{endpoint_name}")

      {:error, changeset} ->
        Logger.warn(inspect(changeset))
    end
  end
end)
