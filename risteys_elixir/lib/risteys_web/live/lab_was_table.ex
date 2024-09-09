defmodule RisteysWeb.Live.LabWASTable do
  use RisteysWeb, :live_view

  def mount(_params, %{"endpoint" => endpoint}, socket) do
    default_sorter = "with-meas-mlog10p_desc"
    init_form = to_form(%{"sorter" => default_sorter})

    all_labwas_rows = Risteys.LabWAS.get_labwas(endpoint)

    socket =
      socket
      |> assign(:form, init_form)
      |> assign(:filter_omop, "")
      |> assign(:filter_unit, "")
      |> assign(:active_sorter, default_sorter)
      |> assign(:all_labwas_rows, all_labwas_rows)
      |> assign(:display_rows, all_labwas_rows)

    {:ok, socket, layout: false}
  end

  def handle_event("sort_table", %{"sorter" => sorter}, socket) do
    socket =
      socket
      |> assign(:active_sorter, sorter)
      |> update_table()

    {:noreply, socket}
  end

  def handle_event("update_table", filters, socket) do
    %{
      "omop-id-name" => filter_omop,
      "mean-value-unit" => filter_unit
    } = filters

    socket =
      socket
      |> assign(:filter_omop, filter_omop)
      |> assign(:filter_unit, filter_unit)
      |> update_table()

    {:noreply, socket}
  end

  defp update_table(socket) do
    display_rows =
      socket.assigns.all_labwas_rows
      |> Enum.filter(fn row ->
        filter_omop_id = String.contains?(row.omop_concept_id, socket.assigns.filter_omop)

        filter_omop_name =
          String.contains?(
            String.downcase(row.omop_concept_name || ""),
            String.downcase(socket.assigns.filter_omop)
          )

        filter_omop = filter_omop_id or filter_omop_name

        filter_unit =
          String.contains?(
            String.downcase(row.mean_value_unit || ""),
            String.downcase(socket.assigns.filter_unit)
          )

        filter_omop and filter_unit
      end)
      |> sort_with_nil(socket.assigns.active_sorter)

    assign(socket, :display_rows, display_rows)
  end

  defp sort_with_nil(elements, sorter) do
    {mapper, direction} =
      case sorter do
        "with-meas-ncases_asc" ->
          {fn row -> row.with_measurement_n_cases end, :asc}

        "with-meas-ncases_desc" ->
          {fn row -> row.with_measurement_n_cases end, :desc}

        "with-meas-ncontrols_asc" ->
          {fn row -> row.with_measurement_n_controls end, :asc}

        "with-meas-ncontrols_desc" ->
          {fn row -> row.with_measurement_n_controls end, :desc}

        "with-meas-odds-ratio_asc" ->
          {fn row -> row.with_measurement_odds_ratio end, :asc}

        "with-meas-odds-ratio_desc" ->
          {fn row -> row.with_measurement_odds_ratio end, :desc}

        "with-meas-mlog10p_asc" ->
          {fn row -> row.with_measurement_mlogp end, :asc}

        "with-meas-mlog10p_desc" ->
          {fn row -> row.with_measurement_mlogp end, :desc}

        "mean-nmeas-cases_asc" ->
          {fn row -> row.mean_n_measurements_cases end, :asc}

        "mean-nmeas-cases_desc" ->
          {fn row -> row.mean_n_measurements_cases end, :desc}

        "mean-nmeas-controls_asc" ->
          {fn row -> row.mean_n_measurements_controls end, :asc}

        "mean-nmeas-controls_desc" ->
          {fn row -> row.mean_n_measurements_controls end, :desc}

        "mean-value-cases_asc" ->
          {fn row -> row.mean_value_cases end, :asc}

        "mean-value-cases_desc" ->
          {fn row -> row.mean_value_cases end, :desc}

        "mean-value-controls_asc" ->
          {fn row -> row.mean_value_controls end, :asc}

        "mean-value-controls_desc" ->
          {fn row -> row.mean_value_controls end, :desc}

        "mean-value-mlog10p_asc" ->
          {fn row -> row.mean_value_mlogp end, :asc}

        "mean-value-mlog10p_desc" ->
          {fn row -> row.mean_value_mlogp end, :desc}

        "mean-value-ncases_asc" ->
          {fn row -> row.mean_value_n_cases end, :asc}

        "mean-value-ncases_desc" ->
          {fn row -> row.mean_value_n_cases end, :desc}

        "mean-value-ncontrols_asc" ->
          {fn row -> row.mean_value_n_controls end, :asc}

        "mean-value-ncontrols_desc" ->
          {fn row -> row.mean_value_n_controls end, :desc}
      end

    Enum.sort_by(elements, mapper, RisteysWeb.Utils.sorter_nil_is_0(direction))
  end
end
