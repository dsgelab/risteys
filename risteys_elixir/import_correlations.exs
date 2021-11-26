alias Risteys.FGEndpoint
alias Risteys.Phenocode
alias Risteys.Repo

import Ecto.Query
require Logger

Logger.configure(level: :info)
[pheno_geno_corr_filepath, geno_variants_filepath | _] = System.argv()

endpoints =
  Repo.all(from pp in Phenocode, select: %{id: pp.id, name: pp.name})
  |> Enum.reduce(%{}, fn %{id: id, name: name}, acc ->
    Map.put_new(acc, name, id)
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

    same_doe = (beta1 > 0 and beta2 > 0) or (beta1 < 0 and beta2 < 0)

    if same_doe do
      Map.update(
        acc,
        {endpoint_a, endpoint_b},
        [variant],
        fn variants -> [variant | variants] end
      )
    else
      acc
    end
  end)

Logger.info("Import phenotypic+genotypic correlations")

pheno_geno_corr_filepath
|> File.stream!()
|> CSV.decode!(headers: true)
|> Enum.each(fn row ->
  %{
    "endpoint_a" => endpoint_a_pheno,
    "endpoint_b" => endpoint_b_pheno,
    "case_ratio" => case_ratio,
    "ratio_shared_of_a" => shared_of_a,
    "ratio_shared_of_b" => shared_of_b,
    "pheno1" => endpoint_a_geno,
    "pheno2" => endpoint_b_geno,
    "n_gwsig_1" => gws_hits_a,
    # not used since redundant with n_gwsig_1
    "n_gwsig_2" => _gws_hits_b,
    "overlap_same_doe" => coloc_gws_hits_same_dir,
    "overlap_diff_doe" => coloc_gws_hits_opp_dir,
    "rel_beta" => rel_beta,
    "rel_beta_opposite_doe" => rel_beta_opp_dir
  } = row

  # For some (a, b) endpoints we might have only the phenotypic info
  # (from endpoint_a, endpoint_b), or only the genotypic info (from
  # pheno1, pheno2).
  {endpoint_a, endpoint_b} =
    case {endpoint_a_pheno, endpoint_b_pheno, endpoint_a_geno, endpoint_b_geno} do
      {a, b, "", ""} -> {a, b}
      {"", "", a, b} -> {a, b}
      {a, b, _a, _b} -> {a, b}
    end

  endpoint_a_id = endpoints[endpoint_a]
  endpoint_b_id = endpoints[endpoint_b]

  case {endpoint_a_id, endpoint_b_id} do
    {nil, nil} ->
      Logger.warn("Skipping row, both endpoints not found: #{endpoint_a}, #{endpoint_b}")

    {nil, _} ->
      Logger.warn("Skipping row, A not found: #{endpoint_a}")

    {_, nil} ->
      Logger.warn("Skipping row, B not found: #{endpoint_b}")

    _ ->
      # Update this endpoint GWS hits
      upsert =
        Repo.get(Phenocode, endpoint_a_id)
        |> Phenocode.changeset(%{gws_hits: gws_hits_a})
        |> Repo.insert_or_update()

      case upsert do
        {:ok, _} ->
          Logger.debug("insert/update ok for GWS hits on #{endpoint_a}")

        {:error, changeset} ->
          Logger.warn(inspect(changeset))
      end

      # Update (a, b) correlations
      variants = Map.get(corr_variants, {endpoint_a, endpoint_b})

      upsert =
        FGEndpoint.upsert_correlation(%{
          phenocode_a_id: endpoint_a_id,
          phenocode_b_id: endpoint_b_id,
          case_ratio: case_ratio,
          shared_of_a: shared_of_a,
          shared_of_b: shared_of_b,
          coloc_gws_hits_same_dir: coloc_gws_hits_same_dir,
          coloc_gws_hits_opp_dir: coloc_gws_hits_opp_dir,
          rel_beta: rel_beta,
          rel_beta_opp_dir: rel_beta_opp_dir,
          variants: variants
        })

      case upsert do
        {:ok, _} ->
          Logger.debug("insert/update ok for A:#{endpoint_a} B:#{endpoint_b}")

        {:error, changeset} ->
          Logger.warn(inspect(changeset))
      end
  end
end)
