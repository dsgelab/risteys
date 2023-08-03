defmodule RisteysWeb.Live.SearchBox do
  use RisteysWeb, :live_view
  require Integer

  def mount(_params, _session, socket) do
    results = []

    socket =
      socket
      |> assign(:form, to_form(%{"search_query" => ""}))
      |> assign(:results, results)
      |> assign(:selected, %{category_index: 0, result_index: 0, endpoint: ""})

    {:ok, socket, layout: false}
  end

  def handle_event("update_search_results", %{"search_query" => ""}, socket) do
    socket = assign(socket, :results, [])
    {:noreply, socket}
  end

  def handle_event("update_search_results", %{"search_query" => query}, socket) do
    results =
      [
        ["ICD-10 code", search_icds(query)],
        ["Endpoint long name", search_longnames(query)],
        ["Description", search_descriptions(query)],
        ["Endpoint name", search_names(query)]
      ]
      |> Enum.reject(fn [_category, result_list] -> Enum.empty?(result_list) end)

    socket = assign(socket, :results, results)
    {:noreply, socket}
  end

  def handle_event("submit_endpoint", _value, socket) do
    socket = redirect(socket, to: ~p"/endpoints/#{socket.assigns.selected.endpoint}")
    {:noreply, socket}
  end

  def handle_event("keydown", %{"key" => "ArrowDown"}, socket) do
    selected = change_selected(socket.assigns.results, socket.assigns.selected, :next)
    socket = assign(socket, :selected, selected)
    {:noreply, socket}
  end

  def handle_event("keydown", %{"key" => "ArrowUp"}, socket) do
    selected = change_selected(socket.assigns.results, socket.assigns.selected, :previous)
    socket = assign(socket, :selected, selected)
    {:noreply, socket}
  end

  def handle_event("keydown", _value, socket) do
    {:noreply, socket}
  end

  defp search_icds(query) do
    Risteys.FGEndpoint.search_icds(query, 10)
    |> Enum.map(fn %{name: name, icds: icds} ->
      icds =
        icds
        # dedup ICDs
        |> MapSet.new()
        |> MapSet.to_list()
        |> Enum.join(", ")

      %{endpoint: name, content: highlight_matches(icds, query), url: ~p"/endpoints/#{name}"}
    end)
  end

  defp search_longnames(query) do
    Risteys.FGEndpoint.search_longnames(query, 10)
    |> Enum.map(fn %{name: name, longname: longname} ->
      %{endpoint: highlight_matches(name, query), content: highlight_matches(longname, query), url: ~p"/endpoints/#{name}"}
    end)
  end

  defp search_descriptions(query) do
    Risteys.FGEndpoint.search_descriptions(query, 10)
    |> Enum.map(fn %{name: name, description: description} ->
      description =
        description
        |> String.split(".")
        |> Enum.filter(fn sentence -> String.contains?(sentence, query) end)
        |> Enum.intersperse("…")
        |> Enum.join("")

      %{endpoint: name, content: highlight_matches(description, query), url: ~p"/endpoints/#{name}"}
    end)
  end

  defp search_names(query) do
    Risteys.FGEndpoint.search_names(query, 10)
    |> Enum.map(fn %{name: name, longname: longname} ->
      %{endpoint: highlight_matches(name, query), content: longname, url: ~p"/endpoints/#{name}"}
    end)
  end

  defp highlight_matches(content, query) do
    regex = Regex.compile!(query, "i")
    content_chunks = Regex.split(regex, content, include_captures: true)

    for {chunk, index} <- Enum.with_index(content_chunks) do
      # matches will be in the indices 1, 3, 5, ...
      if Integer.is_odd(index) do
        Phoenix.HTML.Tag.content_tag(:span, chunk, class: "highlight")
      else
        chunk
      end
    end
  end

  defp change_selected(results, selected, action) do
    flat_index =
      for {[_name, category_results], category_index} <- Enum.with_index(results) do
        for {result, result_index} <- Enum.with_index(category_results) do
          %{category_index: category_index, result_index: result_index, endpoint: result.endpoint}
        end
      end
      |> List.flatten()

    current_index =
      Enum.find_index(flat_index, fn result ->
        result.category_index == selected.category_index and
          result.result_index == selected.result_index
      end)

    new_index =
      case action do
        :next ->
          # min() for bound checking
          min(current_index + 1, length(flat_index))

        :previous ->
          # max(, 0) to prevent cycling the results with a negative index
          max(current_index - 1, 0)
      end

    Enum.at(flat_index, new_index)
  end

  defp aria_expanded?(results) do
    not Enum.empty?(results)
  end

  defp gen_item_id(category_index, result_index) do
    "item__#{category_index}_#{result_index}"
  end

  defp class_selected(selected, category_index, result_index) do
    if selected.category_index == category_index and selected.result_index == result_index do
      "item selected"
    else
      "item"
    end
  end
end
