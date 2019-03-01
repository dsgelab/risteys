defmodule RisteysWeb.CodeController do
  use RisteysWeb, :controller

  def show(conn, %{"phenocode" => code}) do
    # Parse phenos.json
    # TODO should be done once per server worker, no need to do it per request
    pheno =
      "assets/data/myphenos.json"
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!(code)

    conn
    |> assign(:code, code)
    |> assign(:category, Map.fetch!(pheno, "category"))
    |> assign(:title, Map.fetch!(pheno, "description"))
    |> assign(:icd_incl, Map.fetch!(pheno, "icd_incl"))
    |> assign(:icd_excl, Map.fetch!(pheno, "icd_excl"))
    |> assign(:num_cases, Map.fetch!(pheno, "num_cases"))
    |> assign(:num_controls, Map.fetch!(pheno, "num_controls"))
    |> render("show.html")
  end
end
