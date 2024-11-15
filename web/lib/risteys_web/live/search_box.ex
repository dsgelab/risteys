defmodule RisteysWeb.Live.SearchBox do
  use RisteysWeb, :live_view
  require Integer

  def mount(_params, _session, socket) do
    socket = reset_to_empty_query(socket)

    {:ok, socket, layout: false}
  end

  defp reset_to_empty_query(socket) do
    empty_results = %{
      lab_tests: %{
        have_more_results: false,
        top_results: []
      },
      endpoints: %{
        have_more_results: false,
        top_results: []
      }
    }

    socket
    |> assign(:form, to_form(%{"search_query" => ""}))
    |> assign(:user_query, "")
    |> assign(:results, empty_results)
    |> assign(:selected_id, nil)
  end

  def handle_event("update_search_results", %{"search_query" => ""}, socket) do
    socket = reset_to_empty_query(socket)

    {:noreply, socket}
  end

  def handle_event("update_search_results", %{"search_query" => query}, socket) do
    results =
      query
      |> Risteys.SearchEngine.search()
      |> clean_results()
      |> add_result_ids()

    socket =
      socket
      |> assign(:user_query, query)
      |> assign(:results, results)
      |> assign(:selected_id, nil)

    {:noreply, socket}
  end

  def handle_event("submit_endpoint", _value, socket) do
    find_in_lab_tests =
      Enum.find(socket.assigns.results.lab_tests.top_results, fn lab_test ->
        lab_test.result_id == socket.assigns.selected_id
      end)

    find_in_endpoints =
      Enum.find(socket.assigns.results.endpoints.top_results, fn endpoint ->
        endpoint.result_id == socket.assigns.selected_id
      end)

    socket =
      case {find_in_lab_tests, find_in_endpoints} do
        {nil, nil} ->
          socket

        {lab_test, nil} ->
          redirect(socket, to: ~p"/lab-tests/#{lab_test.omop_concept_id}")

        {nil, endpoint} ->
          redirect(socket, to: ~p"/endpoints/#{endpoint.name}")
      end

    {:noreply, socket}
  end

  def handle_event("keydown", %{"key" => "ArrowDown"}, socket) do
    selected_id = change_selected(socket.assigns.results, socket.assigns.selected_id, :next)
    socket = assign(socket, :selected_id, selected_id)
    {:noreply, socket}
  end

  def handle_event("keydown", %{"key" => "ArrowUp"}, socket) do
    selected_id = change_selected(socket.assigns.results, socket.assigns.selected_id, :previous)
    socket = assign(socket, :selected_id, selected_id)
    {:noreply, socket}
  end

  def handle_event("keydown", _value, socket) do
    {:noreply, socket}
  end

  defp change_selected(results, selected_id, :next) do
    case selected_id do
      nil ->
        0

      nn ->
        n_lab_tests = length(results.lab_tests.top_results)
        n_endpoints = length(results.endpoints.top_results)
        min(nn + 1, n_lab_tests + n_endpoints - 1)
    end
  end

  defp change_selected(results, selected_id, :previous) do
    case selected_id do
      nil ->
        n_lab_tests = length(results.lab_tests.top_results)
        n_endpoints = length(results.endpoints.top_results)
        n_lab_tests + n_endpoints - 1

      nn ->
        max(nn - 1, 0)
    end
  end

  # Keep only necessary data fields in the result to minimize the data transfer to the frontend
  defp clean_results(results) do
    %{
      lab_tests: %{
        results.lab_tests
        | top_results: Enum.map(results.lab_tests.top_results, &clean_result(:lab_test, &1))
      },
      endpoints: %{
        results.endpoints
        | top_results: Enum.map(results.endpoints.top_results, &clean_result(:endpoint, &1))
      }
    }
  end

  defp clean_result(:lab_test, result) do
    npeople =
      result.omop_concept_npeople && RisteysWeb.Utils.pretty_number(result.omop_concept_npeople)

    percent =
      result.omop_concept_percent_people_with_two_plus_records

    percent =
      percent && RisteysWeb.Utils.pretty_number(percent) <> "%"

    %{
      omop_concept_id: result.omop_concept_id,
      omop_concept_name: result.omop_concept_name,
      omop_concept_npeople: npeople,
      omop_concept_percent_people_with_two_plus_records: percent
    }
  end

  defp clean_result(:endpoint, result) do
    n_gws_hits = result.n_gws_hits && RisteysWeb.Utils.pretty_number(result.n_gws_hits)
    n_cases = result.n_cases && RisteysWeb.Utils.pretty_number(result.n_cases)

    %{
      name: result.name,
      longname: result.longname,
      n_gws_hits: n_gws_hits,
      n_cases: n_cases,
      icd10_codes: result.icd10_codes,
      icd9_codes: result.icd9_codes
    }
  end

  defp add_result_ids(results) do
    top_lab_tests_with_index =
      for {result, index} <- Enum.with_index(results.lab_tests.top_results) do
        Map.put(result, :result_id, index)
      end

    top_endpoints_with_index =
      for {result, index} <-
            Enum.with_index(results.endpoints.top_results, length(top_lab_tests_with_index)) do
        Map.put(result, :result_id, index)
      end

    results
    |> put_in([:lab_tests, :top_results], top_lab_tests_with_index)
    |> put_in([:endpoints, :top_results], top_endpoints_with_index)
  end

  defp aria_expanded?(results) do
    some_lab_tests? =
      results
      |> get_in([:lab_tests, :top_results])
      |> (fn rows -> not Enum.empty?(rows) end).()

    some_endpoints? =
      results
      |> get_in([:endpoints, :top_results])
      |> (fn rows -> not Enum.empty?(rows) end).()

    some_lab_tests? or some_endpoints?
  end

  defp class_selected(selected_id, result_id) do
    if selected_id == result_id do
      "is_selected"
    else
      ""
    end
  end
end
