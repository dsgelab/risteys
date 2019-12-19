defmodule RisteysWeb.PhenocodeController do
  use RisteysWeb, :controller
  alias Risteys.{Repo, CoxHR, Icd9, Icd10, Phenocode, PhenocodeIcd10, PhenocodeIcd9, StatsSex}
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

  def get_assocs(conn, %{"name" => name}) do
    phenocode = Repo.get_by(Phenocode, name: name)
    assocs = data_assocs(phenocode)

    conn
    |> assign(:phenocode, phenocode)
    |> assign(:assocs, assocs)
    |> render("assocs.json")
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
    |> assign(:h2_liab, phenocode.h2_liab)
    |> assign(:h2_liab_se, phenocode.h2_liab_se)
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
      version: phenocode.version
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
      n_individuals: "N/A",
      prevalence: "N/A",
      mean_age: "N/A",
      median_reoccurence: "N/A",
      reoccurence_rate: "N/A",
      case_fatality: "N/A",
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
end
