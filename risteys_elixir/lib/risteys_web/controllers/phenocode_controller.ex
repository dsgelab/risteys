defmodule RisteysWeb.PhenocodeController do
  use RisteysWeb, :controller

  alias Risteys.{
    Repo,
    ATCDrug,
    CoxHR,
    DrugStats,
    Icd9,
    Icd10,
    Phenocode,
    PhenocodeIcd10,
    PhenocodeIcd9,
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
        prior_distribs = hr_distribs(phenocode, :prior)
        outcome_distribs = hr_distribs(phenocode, :outcome)

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
      if is_nil(distrib_year) do
        %{"hist" => nil}
      else
        distrib_year
      end

    %{"hist" => distrib_age} =
      if is_nil(distrib_age) do
        %{"hist" => nil}
      else
        distrib_age
      end

    conn
    |> assign(:page_title, phenocode.name)
    |> assign(:name, phenocode.name)
    |> assign(:title, phenocode.longname)
    |> assign(:data_sources, data_sources(phenocode))
    |> assign(:ontology, ontology)
    |> assign(:stats, stats)
    |> assign(:distrib_year, distrib_year)
    |> assign(:distrib_age, distrib_age)
    |> assign(:description, description)
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

    hd_icd10s = filter_icds_registry(icd10s, "HD")
    cod_icd10s = filter_icds_registry(icd10s, "COD")
    kela_icd10s = filter_icds_registry(icd10s, "KELA_REIMB")

    icd9s =
      Repo.all(
        from assoc in PhenocodeIcd9,
          join: p in Phenocode,
          on: assoc.phenocode_id == p.id,
          join: icd in Icd9,
          on: assoc.icd9_id == icd.id,
          where: p.id == ^phenocode.id,
          select: %{registry: assoc.registry, icd: icd}
      )

    hd_icd9s = filter_icds_registry(icd9s, "HD")
    cod_icd9s = filter_icds_registry(icd9s, "COD")

    %{
      level: phenocode.level,
      omit: phenocode.omit,
      sex: phenocode.sex,
      include: phenocode.include,
      pre_conditions: phenocode.pre_conditions,
      conditions: phenocode.conditions,
      outpat_icd: phenocode.outpat_icd,
      hd_mainonly: phenocode.hd_mainonly,
      hd_icd_10_atc: phenocode.hd_icd_10_atc,
      hd_icd10s: hd_icd10s,
      hd_icd9s: hd_icd9s,
      hd_icd8s: phenocode.hd_icd_8,
      hd_icd10s_excl: phenocode.hd_icd_10_excl,
      hd_icd9s_excl: phenocode.hd_icd_9_excl,
      hd_icd8s_excl: phenocode.hd_icd_8_excl,
      cod_mainonly: phenocode.cod_mainonly,
      cod_icd10s: cod_icd10s,
      cod_icd9s: cod_icd9s,
      cod_icd8s: phenocode.cod_icd_8,
      cod_icd10s_excl: phenocode.cod_icd_10_excl,
      cod_icd9s_excl: phenocode.cod_icd_9_excl,
      cod_icd8s_excl: phenocode.cod_icd_8_excl,
      oper_nom: phenocode.oper_nom,
      oper_hl: phenocode.oper_hl,
      oper_hp1: phenocode.oper_hp1,
      oper_hp2: phenocode.oper_hp2,
      kela_reimb: phenocode.kela_reimb,
      kela_icd10s: kela_icd10s,
      kela_atc_needother: phenocode.kela_atc_needother,
      kela_atc: phenocode.kela_atc,
      canc_topo: phenocode.canc_topo,
      canc_morph: phenocode.canc_morph,
      version: phenocode.version,
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

  defp hr_distribs(phenocode, direction) do
    distribs =
      hr_distribs_query(phenocode, direction)
      |> Enum.reduce(
        %{},
        fn distrib, acc ->
          {id, stats} = Map.pop(distrib, :assoc_id)
          Map.put_new(acc, id, stats)
        end
      )

    hr_min =
      distribs
      |> Enum.map(fn {_key, %{hr: hr}} -> hr end)
      |> Enum.min(fn -> nil end)

    hr_max =
      distribs
      |> Enum.map(fn {_key, %{hr: hr}} -> hr end)
      |> Enum.max(fn -> nil end)

    %{
      distribs: distribs,
      min: hr_min,
      max: hr_max
    }
  end

  defp hr_distribs_query(phenocode, direction) do
    # Since this function is generic on the "direction", we set what are the fields to select.
    # "main" means the id of the phenocode of interest.
    # "distrib" means ids of the associated phenocodes.
    {field_main_id, field_distrib_id} =
      case direction do
        :prior ->
          {:outcome_id, :prior_id}

        :outcome ->
          {:prior_id, :outcome_id}
      end

    distribs =
      from c in CoxHR,
        where: c.lagged_hr_cut_year == 0,
        group_by: field(c, ^field_distrib_id),
        select: %{
          distrib_id: field(c, ^field_distrib_id),
          cnt: count(field(c, ^field_distrib_id)),
          # Using PostgreSQL specific functions to compute stats on the HR distributions.
          # https://www.postgresql.org/docs/current/functions-aggregate.html
          # Note that we are using ln(HR) to compute everything in the ln space.
          mu: fragment("avg(ln(?))", c.hr),
          sigma: fragment("stddev_pop(ln(?))", c.hr),
          lop: fragment("percentile_cont(0.025) WITHIN GROUP (ORDER BY ln(?))", c.hr),
          q1: fragment("percentile_cont(0.25) WITHIN GROUP (ORDER BY ln(?))", c.hr),
          median: fragment("percentile_cont(0.5) WITHIN GROUP (ORDER BY ln(?))", c.hr),
          q3: fragment("percentile_cont(0.75) WITHIN GROUP (ORDER BY ln(?))", c.hr),
          hip: fragment("percentile_cont(0.975) WITHIN GROUP (ORDER BY ln(?))", c.hr)
        }

    Repo.all(
      from c in CoxHR,
        join: distrib in subquery(distribs),
        on: field(c, ^field_distrib_id) == distrib.distrib_id,
        # 30 to be able to approximate a normal distribution
        where:
          field(c, ^field_main_id) == ^phenocode.id and
            c.lagged_hr_cut_year == 0 and
            distrib.cnt > 30,
        select: %{
          assoc_id: distrib.distrib_id,
          # Centered and normalized values
          # Don't forget to ln(HR) here, other values are already in ln space
          hr: (fragment("ln(?)", c.hr) - distrib.mu) / distrib.sigma,
          lop: (distrib.lop - distrib.mu) / distrib.sigma,
          q1: (distrib.q1 - distrib.mu) / distrib.sigma,
          median: (distrib.median - distrib.mu) / distrib.sigma,
          q3: (distrib.q3 - distrib.mu) / distrib.sigma,
          hip: (distrib.hip - distrib.mu) / distrib.sigma
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
