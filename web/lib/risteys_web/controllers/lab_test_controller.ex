defmodule RisteysWeb.LabTestController do
  use RisteysWeb, :controller

  def index(conn, _params) do
    lab_tests_tree_stats =
      Risteys.OMOP.get_lab_tests_tree()
      |> Risteys.LabTestStats.merge_stats()

    conn
    |> assign(:page_title, "Lab tests")
    |> assign(:lab_tests_tree_stats, lab_tests_tree_stats)
    |> assign(:lab_tests_overall_stats, Risteys.LabTestStats.get_overall_stats())
    |> render(:index)
  end

  def show(conn, %{"omop_id" => omop_id} = _params) do
    pretty_stats =
      omop_id
      |> Risteys.LabTestStats.get_single_lab_test_stats()
      |> RisteysWeb.LabTestHTML.show_prettify_stats()

    main_obsplot =
      case pretty_stats.distributions_lab_values do
        [first | _] -> first.obsplot
        [] -> nil
      end

    conn
    |> assign(:lab_test, pretty_stats)
    |> assign(:main_obsplot, main_obsplot)
    |> render()
  end
end
