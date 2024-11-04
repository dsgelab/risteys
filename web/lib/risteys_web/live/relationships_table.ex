defmodule RisteysWeb.Live.RelationshipsTable do
  use RisteysWeb, :live_view

  def mount(
        _params,
        %{
          "endpoint" => endpoint,
          "is_authz_list_variants" => authz_list_variants?,
          "variants_by_corr" => variants_by_corr
        },
        socket
      ) do
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
      |> assign(:endpoint, endpoint)
      |> assign(:authz_list_variants?, authz_list_variants?)
      |> assign(:variants_by_corr, variants_by_corr)
      |> assign(:form, to_form(init_form))
      |> assign(:active_sorter, default_sorter)
      |> assign(:all_relationships, all_relationships)
      |> assign(:display_relationships, all_relationships)

    {:ok, socket, layout: false}
  end

  def handle_info({:fetch_data, %{endpoint_name: endpoint_name, sorter: sorter}}, socket) do
    data =
      endpoint_name
      |> Risteys.FGEndpoint.get_relationships()
      |> format_relationship_values()
      |> sort_with_nil(sorter, :desc)

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
          # TODO(Vincent) The case_overlap_percent are converted here to float at runtime,
          #   Would be better to have them as number in the DB directly. Keep both str and num if needed.
          "cases-fr_asc" ->
            if is_nil(row.fr_case_overlap_percent),
              do: nil,
              else: String.to_float(row.fr_case_overlap_percent)

          "cases-fr_desc" ->
            if is_nil(row.fr_case_overlap_percent),
              do: nil,
              else: String.to_float(row.fr_case_overlap_percent)

          "cases-fg_asc" ->
            if is_nil(row.fg_case_overlap_percent),
              do: nil,
              else: String.to_float(row.fg_case_overlap_percent)

          "cases-fg_desc" ->
            if is_nil(row.fg_case_overlap_percent),
              do: nil,
              else: String.to_float(row.fg_case_overlap_percent)

          "sa-hr_asc" ->
            row.hr

          "sa-hr_desc" ->
            row.hr

          "gc-rg_asc" ->
            row.rg

          "gc-rg_desc" ->
            row.rg

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

    Enum.sort_by(elements, mapper, RisteysWeb.Utils.sorter_nil_end(direction))
  end

  defp format_relationship_values(table) do
    # To get bonferroni corrected pvalues for FR HR values, threshold for significant pvalue is 0.05 / number of all converged analyses
    # 9773 is number of all converged FR survival analyses in the R10 input data file
    p_threshold = 0.05 / 9773

    # 0.000001 is threshold for significant p-value for FG genetic correlations
    p_sig_fg_corr = 1.0e-6

    Enum.map(table, fn row ->
      row
      |> Map.put(:fr_case_overlap_percent, round_and_str(row.fr_case_overlap_percent, 2))
      |> Map.put(:fg_case_overlap_percent, round_and_str(row.fg_case_overlap_percent, 2))
      |> Map.put(:hr_str, round_and_str(row.hr, 2))
      |> Map.put(:hr_ci_max, round_and_str(row.hr_ci_max, 2))
      |> Map.put(:hr_ci_min, round_and_str(row.hr_ci_min, 2))
      |> Map.put(:hr_pvalue_str, pvalue_star(row.hr_pvalue, p_threshold))
      |> Map.put(:rg_str, round_and_str(row.rg, 2))
      |> Map.put(:rg_ci_min, get_95_ci(row.rg, row.rg_se, "lower") |> round_and_str(2))
      |> Map.put(:rg_ci_max, get_95_ci(row.rg, row.rg_se, "upper") |> round_and_str(2))
      |> Map.put(:rg_pvalue_str, pvalue_star(row.rg_pvalue, p_sig_fg_corr))
    end)
  end

  defp round_and_str(number, precision) do
    case number do
      nil -> nil
      "-" -> "-"
      _ -> :io_lib.format("~.#{precision}. f", [number]) |> to_string()
    end
  end

  defp pvalue_star(pvalue, p_threshold) do
    # statistically significant p-values are presented by "*"
    cond do
      is_nil(pvalue) ->
        nil

      pvalue <= p_threshold ->
        "*"

      true ->
        ""
    end
  end

  defp get_95_ci(estimate, se, direction) do
    if !is_nil(estimate) and !is_nil(se) do
      case direction do
        # 1.96 is z-score for 95% confidence intervals
        "lower" -> estimate - 1.96 * se
        "upper" -> estimate + 1.96 * se
        _ -> nil
      end
    end
  end
end
