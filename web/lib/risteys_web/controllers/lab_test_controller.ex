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
    url_athena_base = "https://athena.ohdsi.org/search-terms/terms/"

    link_athena_lab_test =
      RisteysWeb.CustomHTMLHelpers.ahref_extern(url_athena_base <> omop_id, "OHDSI Athena")

    # OMOP collection
    parent_loinc_component = Risteys.OMOP.get_parent_component(omop_id)

    n_in_collection =
      parent_loinc_component
      |> Risteys.OMOP.list_children_lab_tests()
      |> length()

    n_other_in_collection = n_in_collection - 1

    link_athena_loinc_component =
      RisteysWeb.CustomHTMLHelpers.ahref_extern(
        url_athena_base <> parent_loinc_component.concept_id,
        "OHDSI Athena"
      )

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
    |> assign(:omop_concept_id, omop_id)
    |> assign(:link_athena_lab_test, link_athena_lab_test)
    |> assign(:parent_loinc_component, parent_loinc_component)
    |> assign(:n_other_in_collection, n_other_in_collection)
    |> assign(:link_athena_loinc_component, link_athena_loinc_component)
    |> assign(:lab_test, pretty_stats)
    |> assign(:main_obsplot, main_obsplot)
    |> render()
  end
end
