defmodule RisteysWeb.CodeController do
  use RisteysWeb, :controller

  def show(conn, %{"phenocode" => code}) do
    # Parse phenos.json
    # TODO use a DB
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
    |> render("show.html")
  end
end
