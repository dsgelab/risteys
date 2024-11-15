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
    |> assign(:selected, select_nothing())
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

    socket =
      socket
      |> assign(:user_query, query)
      |> assign(:results, results)

    {:noreply, socket}
  end

  # def handle_event("update_search_results", %{"search_query" => query}, socket) do
  #   results =
  #     [
  #       ["Endpoint name", search_names(query)],
  #       ["ICD-10 code", search_icds(query)],
  #       ["Endpoint long name", search_longnames(query)]
  #     ]
  #     |> Enum.reject(fn [_category, result_list] -> Enum.empty?(result_list) end)

  #   socket = assign(socket, :results, results)

  #   selected =
  #     if Enum.empty?(results) do
  #       select_nothing()
  #     else
  #       select_first(results)
  #     end

  #   socket = assign(socket, :selected, selected)

  #   {:noreply, socket}
  # end

  def handle_event("submit_endpoint", _value, socket) do
    socket = redirect(socket, to: ~p"/endpoints/#{socket.assigns.selected.endpoint}")
    {:noreply, socket}
  end

  # def handle_event("keydown", %{"key" => "ArrowDown"}, socket) do
  #   selected = change_selected(socket.assigns.results, socket.assigns.selected, :next)
  #   socket = assign(socket, :selected, selected)
  #   {:noreply, socket}
  # end

  # def handle_event("keydown", %{"key" => "ArrowUp"}, socket) do
  #   selected = change_selected(socket.assigns.results, socket.assigns.selected, :previous)
  #   socket = assign(socket, :selected, selected)
  #   {:noreply, socket}
  # end

  def handle_event("keydown", _value, socket) do
    {:noreply, socket}
  end

  defp select_nothing() do
    %{
      category_name: nil,
      result_id: nil
    }
  end

  # defp select_nothing() do
  #   %{category_index: nil, result_index: nil, endpoint: nil}
  # end

  # defp select_first(results) do
  #   [[_category_name, [%{endpoint_name: endpoint_name} | _]] | _] = results
  #   %{category_index: 0, result_index: 0, endpoint: endpoint_name}
  # end

  # defp search_icds(query) do
  #   Risteys.FGEndpoint.search_icds(query, 10)
  #   |> Enum.map(fn %{name: name, icds: icds} ->
  #     icds =
  #       icds
  #       # dedup ICDs
  #       |> MapSet.new()
  #       |> MapSet.to_list()
  #       |> Enum.join(", ")

  #     %{
  #       endpoint_name: name,
  #       endpoint_column: name,
  #       content_column: highlight_matches(icds, query)
  #     }
  #   end)
  # end

  # defp search_longnames(query) do
  #   Risteys.FGEndpoint.search_longnames(query, 10)
  #   |> Enum.map(fn %{name: name, longname: longname} ->
  #     %{
  #       endpoint_name: name,
  #       endpoint_column: highlight_matches(name, query),
  #       content_column: highlight_matches(longname, query)
  #     }
  #   end)
  # end

  # defp search_names(query) do
  #   Risteys.FGEndpoint.search_names(query, 10)
  #   |> Enum.map(fn %{name: name, longname: longname} ->
  #     %{
  #       endpoint_name: name,
  #       endpoint_column: highlight_matches(name, query),
  #       content_column: longname
  #     }
  #   end)
  # end

  # defp highlight_matches(content, query) do
  #   regex = Regex.compile!(query, "i")
  #   content_chunks = Regex.split(regex, content, include_captures: true)

  #   for {chunk, index} <- Enum.with_index(content_chunks) do
  #     # matches will be in the indices 1, 3, 5, ...
  #     if Integer.is_odd(index) do
  #       Phoenix.HTML.Tag.content_tag(:span, chunk, class: "highlight")
  #     else
  #       chunk
  #     end
  #   end
  # end

  # defp change_selected(results, selected, action) do
  #   flat_index =
  #     for {[_name, category_results], category_index} <- Enum.with_index(results) do
  #       for {result, result_index} <- Enum.with_index(category_results) do
  #         %{
  #           category_index: category_index,
  #           result_index: result_index,
  #           endpoint: result.endpoint_name
  #         }
  #       end
  #     end
  #     |> List.flatten()

  #   current_index =
  #     Enum.find_index(flat_index, fn result ->
  #       result.category_index == selected.category_index and
  #         result.result_index == selected.result_index
  #     end)

  #   new_index =
  #     case action do
  #       :next ->
  #         # min() for bound checking
  #         min(current_index + 1, length(flat_index) - 1)

  #       :previous ->
  #         # max(, 0) to prevent cycling the results with a negative index
  #         max(current_index - 1, 0)
  #     end

  #   Enum.at(flat_index, new_index)
  # end

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

  defp gen_item_id(nil, nil) do
    nil
  end

  defp gen_item_id(category_name, result_id) do
    "item__#{category_name}_#{result_id}"
  end

  # defp class_selected(selected, category_index, result_index) do
  #   if selected.category_index == category_index and selected.result_index == result_index do
  #     "item selected"
  #   else
  #     "item"
  #   end
  # end
end
