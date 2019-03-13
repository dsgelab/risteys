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

    individuals = Risteys.Data.fake_db(code)

    key_figures = %{
      all: aggregate(individuals, fn _sex -> true end),
      male: aggregate(individuals, fn sex -> sex == 1 end),
      female: aggregate(individuals, fn sex -> sex == 2 end)
    }

    conn
    |> assign(:code, code)
    |> assign(:category, Map.fetch!(pheno, "category"))
    |> assign(:title, Map.fetch!(pheno, "description"))
    |> assign(:icd_incl, Map.fetch!(pheno, "icd_incl"))
    |> assign(:key_figures, key_figures)
    |> render("show.html")
  end

  def aggregate(individuals, sex_filter) do
    ages =
      individuals
      |> Enum.filter(fn %{sex: sex} -> sex_filter.(sex) end)
      |> Enum.map(fn %{age: age} -> age end)

    nevents = length(ages)
    mean_age = Enum.sum(ages) / length(ages)

    %{
      nevents: nevents,
      mean_age: mean_age
    }
  end
end
