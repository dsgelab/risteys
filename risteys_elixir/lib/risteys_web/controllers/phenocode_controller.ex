defmodule RisteysWeb.PhenocodeController do
  use RisteysWeb, :controller

  alias Risteys.{
    Repo,
    ATCDrug,
    DrugStats,
    FGEndpoint,
    MortalityStats,
    Phenocode,
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
    |> assign(:explainer_steps, FGEndpoint.get_explainer_steps(phenocode))
    |> assign(:ontology, ontology)
    |> assign(:broader_endpoints, FGEndpoint.broader_endpoints(phenocode))
    |> assign(:narrower_endpoints, FGEndpoint.narrower_endpoints(phenocode))
    |> assign(:stats, stats)
    |> assign(:distrib_year, distrib_year)
    |> assign(:distrib_age, distrib_age)
    |> assign(:description, description)
    |> assign(:outpat_bump, phenocode.outpat_bump)
    |> assign(:mortality, mortality_stats)
    |> render("show.html")
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

  defp set_filename(conn, filename) do
    resp_headers =
      Enum.concat(
        conn.resp_headers,
        [{"content-disposition", "attachment; filename=\"#{filename}\""}]
      )

    struct!(conn, resp_headers: resp_headers)
  end
end
