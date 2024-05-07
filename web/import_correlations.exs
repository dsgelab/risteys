# Import FinnGen correlation
# Usage: mix run import_correlations.exs <phenotypic_and_genotypic_correlations_csv_file> <coloc_variants_csv_file>

alias Risteys.FGEndpoint
alias Risteys.Repo

require Logger

Logger.configure(level: :info)
[pheno_geno_corr_filepath, geno_variants_filepath | _] = System.argv()

endpoints =
  Repo.all(FGEndpoint.Definition)
  |> Enum.reduce(%{}, fn endpoint, acc ->
  Map.put_new(acc, endpoint.name, endpoint)
end)


Logger.info("Parsing geno variants")

corr_variants =
  geno_variants_filepath
  |> File.stream!()
  |> CSV.decode!(headers: true)
  |> Enum.reduce(%{}, fn row, acc ->
    %{
      "pheno1" => endpoint_a,
      "pheno2" => endpoint_b,
      "variant" => variant,
      "beta1" => beta1,
      "beta2" => beta2
    } = row

    # Reformat variant to format used in PheWeb URL: CHR-POS-REF-ALT
    variant =
      variant
      |> String.trim_leading("chr")
      |> String.replace("_", "-")

    # We are showing coloc GWS hits with same direction of effect (doe), so only import those.
    {beta1, _} = Float.parse(beta1)
    {beta2, _} = Float.parse(beta2)

    variant_dir =
      if (beta1 > 0 and beta2 > 0) or (beta1 < 0 and beta2 < 0) do
        :same_dir
      else
        :opp_dir
      end

    Map.update(
      acc,
      {endpoint_a, endpoint_b, variant_dir},
      [variant],
      fn variants -> [variant | variants] end
    )
  end)

Logger.info("Import phenotypic+genotypic correlations")

pheno_geno_corr_filepath
|> File.stream!()
|> CSV.decode!(headers: true)

# Replace empty strings with nil in phenotypic info for easier processing afterwards
|> Stream.map(fn row ->
  empty_to_nil = fn val -> if val == "", do: nil, else: val end
  row = %{row | "pheno1" => empty_to_nil.(row["pheno1"])}
  row = %{row | "pheno2" => empty_to_nil.(row["pheno2"])}
  row = %{row | "n_gwsig_1" => empty_to_nil.(row["n_gwsig_1"])}
  row = %{row | "n_gwsig_2" => empty_to_nil.(row["n_gwsig_2"])}
  row = %{row | "overlap_same_doe" => empty_to_nil.(row["overlap_same_doe"])}
  row = %{row | "overlap_diff_doe" => empty_to_nil.(row["overlap_diff_doe"])}
  row = %{row | "rel_beta" => empty_to_nil.(row["rel_beta"])}
  %{row | "rel_beta_opposite_doe" => empty_to_nil.(row["rel_beta_opposite_doe"])}
end)
|> Enum.each(fn row ->
  %{
    "endpoint_a" => endpoint_a_pheno,
    "endpoint_b" => endpoint_b_pheno,
    "jaccard_index" => jaccard_index,
    "case_overlap_N" => case_overlap_N,
    "ratio_shared_of_a" => shared_of_a,
    "ratio_shared_of_b" => shared_of_b,
    "pheno1" => endpoint_a_geno,
    "pheno2" => endpoint_b_geno,
    "n_gwsig_1" => gws_hits_a,
    # not used since redundant with n_gwsig_1
    "n_gwsig_2" => _gws_hits_b,
    "overlap_same_doe" => coloc_gws_hits_same_dir,
    "overlap_diff_doe" => coloc_gws_hits_opp_dir,
    "rel_beta" => rel_beta_same_dir,
    "rel_beta_opposite_doe" => rel_beta_opp_dir
  } = row

  # For some (a, b) endpoints we might have only the phenotypic info
  # (from endpoint_a, endpoint_b), or only the genotypic info (from
  # pheno1, pheno2).
  {endpoint_a_name, endpoint_b_name} =
    case {endpoint_a_pheno, endpoint_b_pheno, endpoint_a_geno, endpoint_b_geno} do
      {a, b, "", ""} -> {a, b}
      {"", "", a, b} -> {a, b}
      {a, b, _a, _b} -> {a, b}
    end

  endpoint_a = endpoints[endpoint_a_name]
  endpoint_b = endpoints[endpoint_b_name]

  case {endpoint_a, endpoint_b} do
    {nil, nil} ->
      Logger.warning("Skipping row, both endpoints not found: #{endpoint_a_name}, #{endpoint_b_name}")

    {nil, _} ->
      Logger.warning("Skipping row, A not found: #{endpoint_a_name}")

    {_, nil} ->
      Logger.warning("Skipping row, B not found: #{endpoint_b_name}")

    _ ->
      # Update GWS hits of endpoint A.
      # Sometimes an endpoint pair in the input file has no genotypic
      # info, so no GWS hits info is set for that particular
      # pair. However, that doesn't mean this endpoint has no GWS
      # hits! The info for this endpoint GWS hits can exist in other
      # endpoint pairs where the genotypic info is available.
      # So here we make sure to not overwrite the GWS hits info when
      # we are looking at a pair that doesn't have any genotypic info.
      gws_hits_a = gws_hits_a || endpoint_a.gws_hits

      upsert =
        endpoint_a
        |> FGEndpoint.Definition.changeset(%{gws_hits: gws_hits_a})
        |> Repo.insert_or_update()

      case upsert do
        {:ok, _} ->
          Logger.debug("insert/update ok for GWS hits on #{endpoint_a.name}")

        {:error, changeset} ->
          Logger.warning(inspect(changeset))
      end

      # Update (a, b) correlations
      variants_same_dir = Map.get(corr_variants, {endpoint_a.name, endpoint_b.name, :same_dir}, [])
      variants_opp_dir = Map.get(corr_variants, {endpoint_a.name, endpoint_b.name, :opp_dir}, [])

      # multiply by 100 to get percentage
      jaccard_index = if jaccard_index == "", do: nil, else: (Float.parse(jaccard_index) |> elem(0)) * 100

      case_overlap_N = if case_overlap_N == "", do: nil, else: String.to_integer(case_overlap_N)

      # Split same vs. opposite direction-of-effect variants
      upsert =
        FGEndpoint.upsert_correlation(%{
          fg_endpoint_a_id: endpoint_a.id,
          fg_endpoint_b_id: endpoint_b.id,
          case_overlap_percent: jaccard_index,
          case_overlap_N: case_overlap_N,
          shared_of_a: shared_of_a,
          shared_of_b: shared_of_b,
          coloc_gws_hits_same_dir: coloc_gws_hits_same_dir,
          coloc_gws_hits_opp_dir: coloc_gws_hits_opp_dir,
          rel_beta_same_dir: rel_beta_same_dir,
          rel_beta_opp_dir: rel_beta_opp_dir,
          variants_same_dir: variants_same_dir,
          variants_opp_dir: variants_opp_dir
        })

      case upsert do
        {:ok, _} ->
          Logger.debug("insert/update ok for A:#{endpoint_a.name} B:#{endpoint_b.name}")

        {:error, changeset} ->
          Logger.warning(inspect(changeset))
      end
  end
end)
