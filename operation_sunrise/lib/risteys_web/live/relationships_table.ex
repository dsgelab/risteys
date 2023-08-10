defmodule RisteysWeb.Live.RelationshipsTable do
  use RisteysWeb, :live_view

  def mount(_params, %{"endpoint" => endpoint}, socket) do
    default_sorter = "sa-hr_desc"

    # Trick to make the initial render non-blocking.
    # Fetching the data is currently slow (~ 5s) and doing it here on mount would mean
    # that we block the initial *static render* of the page for that long.
    # So instead we make an empty table for the static render, and then immediatly fetch
    # the actual data in the background and non-blockingly display it on the client when
    # the data is ready.
    Process.send(
      self(),
      {:fetch_data, %{endpoint_name: endpoint.name, sorter: default_sorter}},
      []
    )

    init_form = to_form(%{"sorter" => default_sorter})

    all_relationships = []

    socket =
      socket
      |> assign(:form, to_form(init_form))
      |> assign(:active_sorter, default_sorter)
      |> assign(:all_relationships, all_relationships)
      |> assign(:display_relationships, all_relationships)

    {:ok, socket, layout: false}
  end

  def handle_info({:fetch_data, %{endpoint_name: endpoint_name, sorter: sorter}}, socket) do
    data = sort_with_nil(Risteys.FGEndpoint.get_relationships(endpoint_name), sorter, :desc)

    socket =
      socket
      |> assign(:all_relationships, data)
      |> assign(:display_relationships, data)

    {:noreply, socket}
  end

  def handle_event("update_table", %{"endpoint-filter" => filter}, socket) do
    filter = String.downcase(filter)

    display_relationships =
      socket.assigns.all_relationships
      |> Enum.filter(fn row ->
        row.name |> String.downcase() |> String.contains?(filter) or
          row.longname |> String.downcase() |> String.contains?(filter)
      end)

    socket = assign(socket, :display_relationships, display_relationships)
    {:noreply, socket}
  end

  def handle_event("sort_table", %{"sorter" => sorter}, socket) do
    sort_direction =
      if String.ends_with?(sorter, "_asc") do
        :asc
      else
        :desc
      end

    display_relationships =
      sort_with_nil(socket.assigns.display_relationships, sorter, sort_direction)

    socket =
      socket
      |> assign(:display_relationships, display_relationships)
      |> assign(:active_sorter, sorter)

    {:noreply, socket}
  end

  defp sort_with_nil(elements, sorter, direction) do
    # Put the nil values at the end of the list, independent of the sorting direction
    mapper =
      fn row ->
        case sorter do
          "cases-fr_asc" ->
            row.fr_case_overlap_percent

          "cases-fr_desc" ->
            row.fr_case_overlap_percent

          "cases-fg_asc" ->
            row.fg_case_overlap_percent

          "cases-fg_desc" ->
            row.fg_case_overlap_percent

          "sa-hr_asc" ->
            row.hr

          "sa-hr_desc" ->
            row.hr

          "sa-extremity_asc" ->
            row.hr_binned

          "sa-extremity_desc" ->
            row.hr_binned

          "gc-rg_asc" ->
            row.rg

          "gc-rg_desc" ->
            row.rg

          "gc-extremity_asc" ->
            row.rg_binned

          "gc-extremity_desc" ->
            row.rg_binned

          "gs-hits_asc" ->
            row.gws_hits

          "gs-hits_desc" ->
            row.gws_hits

          "gs-coloc-hits_asc" ->
            row.coloc_gws_hits

          "gs-coloc-hits_desc" ->
            row.coloc_gws_hits
        end
      end

    Enum.sort_by(elements, mapper, fn aa, bb ->
      case {aa, bb, direction} do
        {nil, _, _} -> false
        {_, nil, _} -> true
        {_, _, :asc} -> aa < bb
        {_, _, :desc} -> aa > bb
      end
    end)
  end

  defp sorter_buttons(column, form_id, active_sorter) do
    [
      gen_button(:asc, column, form_id, active_sorter),
      gen_button(:desc, column, form_id, active_sorter)
    ]
  end

  defp gen_button(direction, column, form_id, active_sorter) do
    content =
      case direction do
        :asc ->
          "▲"

        :desc ->
          "▼"
      end

    value =
      case direction do
        :asc ->
          column <> "_asc"

        :desc ->
          column <> "_desc"
      end

    class =
      case {direction, active_sorter} do
        {:asc, ^value} ->
          "radio-left active"

        {:asc, _} ->
          "radio-left"

        {:desc, ^value} ->
          "radio-right active"

        {:desc, _} ->
          "radio-right"
      end

    Phoenix.HTML.Tag.content_tag(
      :button,
      content,
      name: "sorter",
      value: value,
      form: form_id,
      class: class
    )
  end
end
