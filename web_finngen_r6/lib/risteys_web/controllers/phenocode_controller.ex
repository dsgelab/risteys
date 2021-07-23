defmodule RisteysWeb.PhenocodeController do
  use RisteysWeb, :controller

  alias Risteys.{
    Repo,
    ATCDrug,
    CoxHR,
    DrugStats,
    FGEndpoint,
    Icd10,
    MortalityStats,
    Phenocode,
    PhenocodeIcd10,
    StatsSex
  }

  import Ecto.Query

  def show(conn, %{"name" => name}) do
    case Repo.get_by(Phenocode, name: name) do
      nil ->
        conn
        |> assign(:page_title, "404 Not Found: #{name}")
        |> assign(:name, name)
        |> put_status(:not_found)
        |> put_view(RisteysWeb.ErrorView)
        |> render("404.html")

      phenocode ->
        show_phenocode(conn, phenocode)
    end
  end

  def get_assocs_json(conn, params) do
    get_assocs(conn, params, :json)
  end

  def get_assocs_csv(conn, params) do
    get_assocs(conn, params, :csv)
  end

  defp get_assocs(conn, %{"name" => name}, format) do
    # Set filename to have the endpoint name, for clarity to the users once the file is downloaded
    conn = set_filename(conn, name <> "_survival-analyses.csv")

    phenocode = Repo.get_by(Phenocode, name: name)
    assocs = data_assocs(phenocode)

    conn =
      conn
      |> assign(:phenocode, phenocode)
      |> assign(:assocs, assocs)

    case format do
      :json ->
        # These are only needed on the JSON API
        prior_distribs = hr_prior_distribs(phenocode)
        outcome_distribs = hr_outcome_distribs(phenocode)

        conn
        |> assign(:hr_prior_distribs, prior_distribs)
        |> assign(:hr_outcome_distribs, outcome_distribs)
        |> render("assocs.json")

      :csv ->
        render(conn, "assocs.csv")
    end
  end

  def get_drugs_json(conn, params) do
    get_drugs(conn, params, :json)
  end

  def get_drugs_csv(conn, params) do
    get_drugs(conn, params, :csv)
  end

  defp get_drugs(conn, %{"name" => name}, format) do
    conn = set_filename(conn, name <> "_drugs.csv")
    phenocode = Repo.get_by(Phenocode, name: name)

    drug_stats =
      Repo.all(
        from dstats in DrugStats,
          join: drug in ATCDrug,
          on: drug.id == dstats.atc_id,
          where: dstats.phenocode_id == ^phenocode.id,
          order_by: [desc: :score],
          select: %{
            description: drug.description,
            score: dstats.score,
            pvalue: dstats.pvalue,
            stderr: dstats.stderr,
            n_indivs: dstats.n_indivs,
            atc: drug.atc
          }
      )

    conn = assign(conn, :drug_stats, drug_stats)

    case format do
      :json -> render(conn, "drugs.json")
      :csv -> render(conn, "drugs.csv")
    end
  end

  defp show_phenocode(conn, phenocode) do
    description =
      if not is_nil(phenocode.description) do
        phenocode.description
      else
        "No definition available."
      end

    ontology =
      if not is_nil(phenocode.ontology) do
        phenocode.ontology
      else
        %{}
      end

    # Get stats
    stats = get_stats(phenocode)
    %{all: %{distrib_year: distrib_year, distrib_age: distrib_age}} = stats

    # Unwrap histograms
    %{"hist" => distrib_year} =
      case distrib_year do
        nil ->
          %{"hist" => nil}

        [] ->
          %{"hist" => nil}

        _ ->
          distrib_year
      end

    %{"hist" => distrib_age} =
      case distrib_age do
        nil ->
          %{"hist" => nil}

        [] ->
          %{"hist" => nil}

        _ ->
          distrib_age
      end

    # Mortality stats
    mortality_stats = get_mortality_stats(phenocode)


    # TMP quickfix
    distrib_year = %{}
    distrib_age = %{}

    conn
    |> assign(:endpoint, phenocode)
    |> assign(:page_title, phenocode.name)
    |> assign(:data_sources, data_sources(phenocode))
    |> assign(:ontology, ontology)
    |> assign(:broader_endpoints, FGEndpoint.broader_endpoints(phenocode))
    |> assign(:narrower_endpoints, FGEndpoint.narrower_endpoints(phenocode))
    |> assign(:stats, stats)
    |> assign(:distrib_year, distrib_year)
    |> assign(:distrib_age, distrib_age)
    |> assign(:description, description)
    |> assign(:outpat_bump, phenocode.outpat_bump)
    |> assign(:mortality, mortality_stats)
    |> assign(:data_assocs, data_assocs(phenocode))
    |> render("show.html")
  end

  defp data_sources(phenocode) do
    icd10s =
      Repo.all(
        from assoc in PhenocodeIcd10,
          join: p in Phenocode,
          on: assoc.phenocode_id == p.id,
          join: icd in Icd10,
          on: assoc.icd10_id == icd.id,
          where: p.id == ^phenocode.id,
          select: %{registry: assoc.registry, icd: icd}
      )

    outpat_icd10s = filter_icds_registry(icd10s, "OUTPAT")
    hd_icd10s = filter_icds_registry(icd10s, "HD")
    hd_icd10s_excl = filter_icds_registry(icd10s, "HD_EXCL")
    cod_icd10s = filter_icds_registry(icd10s, "COD")
    cod_icd10s_excl = filter_icds_registry(icd10s, "COD_EXCL")
    kela_icd10s = filter_icds_registry(icd10s, "KELA")

    %{
      name: phenocode.name,
      tags: phenocode.tags,
      level: phenocode.level,
      omit: phenocode.omit,
      longname: phenocode.longname,
      sex: phenocode.sex,
      include: phenocode.include,
      pre_conditions: phenocode.pre_conditions,
      conditions: phenocode.conditions,
      outpat_icd_10s_exp: outpat_icd10s,
      outpat_icd: phenocode.outpat_icd,
      hd_mainonly: phenocode.hd_mainonly,
      hd_icd_10_atc: phenocode.hd_icd_10_atc,
      hd_icd_10s_exp: hd_icd10s,
      hd_icd_10: phenocode.hd_icd_10,
      hd_icd_9: phenocode.hd_icd_9,
      hd_icd_8: phenocode.hd_icd_8,
      hd_icd_10s_excl_exp: hd_icd10s_excl,
      hd_icd_10_excl: phenocode.hd_icd_10_excl,
      hd_icd_9_excl: phenocode.hd_icd_9_excl,
      hd_icd_8_excl: phenocode.hd_icd_8_excl,
      cod_mainonly: phenocode.cod_mainonly,
      cod_icd_10s_exp: cod_icd10s,
      cod_icd_10: phenocode.cod_icd_10,
      cod_icd_9: phenocode.cod_icd_9,
      cod_icd_8: phenocode.cod_icd_8,
      cod_icd_10s_excl_exp: cod_icd10s_excl,
      cod_icd_10_excl: phenocode.cod_icd_10_excl,
      cod_icd_9_excl: phenocode.cod_icd_9_excl,
      cod_icd_8_excl: phenocode.cod_icd_8_excl,
      oper_nom: phenocode.oper_nom,
      oper_hl: phenocode.oper_hl,
      oper_hp1: phenocode.oper_hp1,
      oper_hp2: phenocode.oper_hp2,
      kela_reimb: phenocode.kela_reimb,
      kela_icd_10s_exp: kela_icd10s,
      kela_reimb_icd: phenocode.kela_reimb_icd,
      kela_atc_needother: phenocode.kela_atc_needother,
      kela_atc: phenocode.kela_atc,
      kela_vnro_needother: phenocode.kela_vnro_needother,
      kela_vnro: phenocode.kela_vnro,
      canc_topo: phenocode.canc_topo,
      canc_topo_excl: phenocode.canc_topo_excl,
      canc_morph: phenocode.canc_morph,
      canc_morph_excl: phenocode.canc_morph_excl,
      canc_behav: phenocode.canc_behav,
      special: phenocode.special,
      version: phenocode.version,
      parent: phenocode.parent,
      latin: phenocode.latin
    }
  end

  defp filter_icds_registry(icds, wanted_registry) do
    Enum.reduce(icds, [], fn %{registry: registry, icd: icd}, acc ->
      if registry == wanted_registry do
        acc ++ [icd]
      else
        acc
      end
    end)
  end

  defp get_stats(phenocode) do
    stats = Repo.all(from ss in StatsSex, where: ss.phenocode_id == ^phenocode.id)

    no_stats = %{
      n_individuals: "-",
      prevalence: "-",
      mean_age: "-",
      distrib_year: [],
      distrib_age: []
    }

    stats_all =
      case Enum.filter(stats, fn stats_sex -> stats_sex.sex == 0 end) do
        [] -> no_stats
        values -> hd(values)
      end

    stats_female =
      case Enum.filter(stats, fn stats_sex -> stats_sex.sex == 2 end) do
        [] -> no_stats
        values -> hd(values)
      end

    stats_male =
      case Enum.filter(stats, fn stats_sex -> stats_sex.sex == 1 end) do
        [] -> no_stats
        values -> hd(values)
      end

    %{
      all: stats_all,
      female: stats_female,
      male: stats_male
    }
  end

  defp get_mortality_stats(phenocode) do
    Repo.all(from ms in MortalityStats, where: ms.phenocode_id == ^phenocode.id)
  end

  defp data_assocs(phenocode) do
    query =
      from assoc in CoxHR,
        join: prior in Phenocode,
        on: assoc.prior_id == prior.id,
        join: outcome in Phenocode,
        on: assoc.outcome_id == outcome.id,
        where: assoc.prior_id == ^phenocode.id or assoc.outcome_id == ^phenocode.id,
        order_by: [desc: assoc.hr],
        select: %{
          prior_id: prior.id,
          prior_name: prior.name,
          prior_longname: prior.longname,
          prior_category: prior.category,
          outcome_id: outcome.id,
          outcome_name: outcome.name,
          outcome_longname: outcome.longname,
          outcome_category: outcome.category,
          lagged_hr_cut_year: assoc.lagged_hr_cut_year,
          hr: assoc.hr,
          ci_min: assoc.ci_min,
          ci_max: assoc.ci_max,
          pvalue: assoc.pvalue,
          nindivs: assoc.n_individuals
        }

    Repo.all(query)
  end

  defp hr_prior_distribs(phenocode) do
    # at least that amount for a meaningful distribution
    min_count = 30

    percs =
      from c in CoxHR,
        where: c.lagged_hr_cut_year == 0,
        select: %{
          prior_id: c.prior_id,
          outcome_id: c.outcome_id,
          percent_rank:
            fragment(
              "percent_rank() OVER (PARTITION BY ? ORDER BY ?)",
              c.prior_id,
              c.hr
            )
        }

    counts =
      from c in CoxHR,
        where: c.lagged_hr_cut_year == 0,
        group_by: c.prior_id,
        select: %{
          prior_id: c.prior_id,
          count: count()
        }

    Repo.all(
      from p in subquery(percs),
        join: cnt in subquery(counts),
        on: p.prior_id == cnt.prior_id,
        where: p.outcome_id == ^phenocode.id and cnt.count > ^min_count,
        select: %{
          pheno_id: p.prior_id,
          percent_rank: p.percent_rank
        }
    )
  end

  defp hr_outcome_distribs(phenocode) do
    # at least that amount for a meaningful distribution
    min_count = 30

    percs =
      from c in CoxHR,
        where: c.lagged_hr_cut_year == 0,
        select: %{
          prior_id: c.prior_id,
          outcome_id: c.outcome_id,
          percent_rank:
            fragment(
              "percent_rank() OVER (PARTITION BY ? ORDER BY ?)",
              c.outcome_id,
              c.hr
            )
        }

    counts =
      from c in CoxHR,
        where: c.lagged_hr_cut_year == 0,
        group_by: c.outcome_id,
        select: %{
          outcome_id: c.outcome_id,
          count: count()
        }

    Repo.all(
      from p in subquery(percs),
        join: cnt in subquery(counts),
        on: p.outcome_id == cnt.outcome_id,
        where: p.prior_id == ^phenocode.id and cnt.count > ^min_count,
        select: %{
          pheno_id: p.outcome_id,
          percent_rank: p.percent_rank
        }
    )
  end

  defp set_filename(conn, filename) do
    resp_headers =
      Enum.concat(
        conn.resp_headers,
        [{"content-disposition", "attachment; filename=\"#{filename}\""}]
      )

    struct!(conn, resp_headers: resp_headers)
  end
end
