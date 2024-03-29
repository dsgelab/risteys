defmodule RisteysWeb.FGEndpointController do
  use RisteysWeb, :controller

  alias Risteys.{
    Repo,
    ATCDrug,
    CoxHR,
    DrugStats,
    FGEndpoint,
    KeyFigures
  }
  import Ecto.Query

  def redirect_legacy_url(conn, %{"name" => name}) do
    conn
    |> put_status(:moved_permanently)
    |> redirect(to: Routes.fg_endpoint_path(conn, :show, name))
  end

  def show(conn, %{"name" => name}) do
    case Repo.get_by(FGEndpoint.Definition, name: name) do
      nil ->
        conn
        |> assign(:page_title, "404 Not Found: #{name}")
        |> assign(:name, name)
        |> put_status(:not_found)
        |> put_view(RisteysWeb.ErrorView)
        |> render("404.html")

      endpoint ->
        show_endpoint(conn, endpoint)
    end
  end

  def redir_random(conn, _params) do
    endpoint = FGEndpoint.get_random_endpoint()

    redirect(conn, to: Routes.fg_endpoint_path(conn, :show, endpoint.name))
  end

  def index_json(conn, _params) do
    endpoints = FGEndpoint.list_endpoint_names()

    conn
    |> assign(:endpoints, endpoints)
    |> render("index.json")
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

    endpoint = Repo.get_by(FGEndpoint.Definition, name: name)
    assocs = data_assocs(endpoint)

    conn =
      conn
      |> assign(:endpoint, endpoint)
      |> assign(:assocs, assocs)

    case format do
      :json ->
        # These are only needed on the JSON API
        prior_distribs = hr_prior_distribs(endpoint)
        outcome_distribs = hr_outcome_distribs(endpoint)

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
    endpoint = Repo.get_by(FGEndpoint.Definition, name: name)

    drug_stats =
      Repo.all(
        from dstats in DrugStats,
          join: drug in ATCDrug,
          on: drug.id == dstats.atc_id,
          where: dstats.fg_endpoint_id == ^endpoint.id,
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

  defp show_endpoint(conn, endpoint) do
    description =
      if not is_nil(endpoint.description) do
        endpoint.description
      else
        "No definition available."
      end

    ontology =
      if not is_nil(endpoint.ontology) do
        endpoint.ontology
      else
        %{}
      end

    # Get key figures
    key_figures_FG = get_key_figures(endpoint, "FG")
    key_figures_FR = get_key_figures(endpoint, "FR")
    key_figures_FR_index = get_key_figures(endpoint, "FR_index")

    # Variants in correlations
    authz_list_variants? =
      case get_session(conn, :user_is_authz) do
        # authz is nil when login was never done
        nil -> false
        authz -> authz
      end

    variants_by_corr =
      if authz_list_variants? do
        FGEndpoint.list_variants_by_correlation(endpoint)
      else
        []
      end

    conn
    |> assign(:endpoint, endpoint)
    |> assign(:page_title, endpoint.name)
    |> assign(:replacements, FGEndpoint.find_replacement_endpoints(endpoint))
    |> assign(:explainer_steps, FGEndpoint.get_explainer_steps(endpoint))
    |> assign(:count_registries, FGEndpoint.get_count_registries(endpoint))
    |> assign(:ontology, ontology)
    |> assign(:broader_endpoints, FGEndpoint.broader_endpoints(endpoint))
    |> assign(:narrower_endpoints, FGEndpoint.narrower_endpoints(endpoint))
    |> assign(:key_figures_FG, key_figures_FG)
    |> assign(:key_figures_FR, key_figures_FR)
    |> assign(:key_figures_FR_index, key_figures_FR_index)
    |> assign(:description, description)
    |> assign(:data_assocs, data_assocs(endpoint))
    |> assign(:has_drug_stats, FGEndpoint.has_drug_stats?(endpoint))
    |> assign(:authz_list_variants?, authz_list_variants?)
    |> assign(:variants_by_corr, variants_by_corr)
    |> render("show.html")
  end

  defp get_key_figures(endpoint, dataset) do
    key_fig =
      Repo.one(from kf in KeyFigures,
      where: kf.fg_endpoint_id == ^endpoint.id and kf.dataset == ^dataset,
      select: %{
        fg_endpoint_id: kf.fg_endpoint_id,
        nindivs_all: kf.nindivs_all,
        nindivs_female: kf.nindivs_female,
        nindivs_male: kf.nindivs_male,
        median_age_all: kf.median_age_all,
        median_age_female: kf.median_age_female,
        median_age_male: kf.median_age_male,
        prevalence_all: kf.prevalence_all,
        prevalence_female: kf.prevalence_female,
        prevalence_male: kf.prevalence_male,
        dataset: kf.dataset
      })

    no_key_figures = %{
      fg_endpoint_id: "-",
      nindivs_all: "-",
      nindivs_female: "-",
      nindivs_male: "-",
      median_age_all: "-",
      median_age_female: "-",
      median_age_male: "-",
      prevalence_all: "-",
      prevalence_female: "-",
      prevalence_male: "-",
      dataset: "-"
    }

    # create and return key_figures
    case key_fig do
      nil -> no_key_figures
      _ ->
        Enum.reduce(
          key_fig,
          %{},
          fn {k, v}, acc ->
            case v do
              nil -> Map.put(acc, k, "-")
              _ -> Map.put(acc, k, v)
            end
          end
        )
    end
  end

  defp data_assocs(endpoint) do
    query =
      from assoc in CoxHR,
        join: prior in FGEndpoint.Definition,
        on: assoc.prior_id == prior.id,
        join: outcome in FGEndpoint.Definition,
        on: assoc.outcome_id == outcome.id,
        where: assoc.prior_id == ^endpoint.id or assoc.outcome_id == ^endpoint.id,
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

  defp hr_prior_distribs(endpoint) do
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
      from endpoint in subquery(percs),
        join: cnt in subquery(counts),
        on: endpoint.prior_id == cnt.prior_id,
        where: endpoint.outcome_id == ^endpoint.id and cnt.count > ^min_count,
        select: %{
          endpoint_id: endpoint.prior_id,
          percent_rank: endpoint.percent_rank
        }
    )
  end

  defp hr_outcome_distribs(endpoint) do
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
      from endpoint in subquery(percs),
        join: cnt in subquery(counts),
        on: endpoint.outcome_id == cnt.outcome_id,
        where: endpoint.prior_id == ^endpoint.id and cnt.count > ^min_count,
        select: %{
          endpoint_id: endpoint.outcome_id,
          percent_rank: endpoint.percent_rank
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
