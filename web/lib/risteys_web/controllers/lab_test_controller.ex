defmodule RisteysWeb.LabTestController do
  use RisteysWeb, :controller

  def index(conn, _params) do
    lab_tests_tree_stats =
      Risteys.OMOP.get_lab_tests_tree()
      |> Risteys.LabTestStats.merge_stats()

    conn
    |> assign(:page_title, "Lab tests")
    |> assign(:lab_tests_tree_stats, lab_tests_tree_stats)
    |> assign(:lab_tests_loinc_component_stats, Risteys.LabTestStats.get_loinc_component_stats())
    |> assign(:lab_tests_overall_stats, Risteys.LabTestStats.get_overall_stats())
    |> render(:index)
  end
end
