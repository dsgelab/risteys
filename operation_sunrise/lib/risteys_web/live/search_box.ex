defmodule RisteysWeb.Live.SearchBox do
  use RisteysWeb, :live_view

  def mount(_params, _session, socket) do
    # TODO
    mock_results =
      [
        [
          "Endpoint long name",
          [
            %{endpoint: "endpoint1", content: "cont"},
            %{endpoint: "endpoint2", content: "content"},
            %{endpoint: "endpoint3", content: "content"},
            %{endpoint: "endpoint1", content: "cont"},
            %{endpoint: "endpoint2", content: "content"},
            %{endpoint: "endpoint3", content: "content"}
          ]
        ],
        [
          "ICD-10 code",
          [
            %{endpoint: "endpoint4", content: "content"},
            %{endpoint: "endpoint5", content: "content"}
          ]
        ],
        [
          "Description",
          [
            %{endpoint: "endpoint7", content: "content"},
            %{endpoint: "endpoint8", content: "content"},
            %{endpoint: "endpoint9", content: "content"},
            %{endpoint: "endpoint9", content: "content"}
          ]
        ],
        [
          "Endpoint name",
          [
            %{endpoint: "endpoint10", content: "content"},
            %{endpoint: "endpoint11", content: "content"},
            %{endpoint: "endpoint12", content: "content"}
          ]
        ]
      ]

    socket =
      socket
      |> assign(:form, to_form(%{"search_query" => ""}))
      |> assign(:results, mock_results)
      |> assign(:selected, %{category_index: 0, result_index: 0, endpoint: ""})

    {:ok, socket, layout: false}
  end

  def handle_event("update_search_results", _value, socket) do
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
