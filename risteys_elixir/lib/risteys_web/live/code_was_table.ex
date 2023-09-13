defmodule RisteysWeb.Live.CodeWASTable do
  use RisteysWeb, :live_view

  def mount(_params, %{"endpoint" => endpoint}, socket) do
    default_sorter = "nlog10p_desc"

    init_form = to_form(%{"sorter" => default_sorter})

    all_codes = Risteys.CodeWAS.list_codes(endpoint)

    socket =
      socket
      |> assign(:form, init_form)
      |> assign(:active_sorter, default_sorter)
      |> assign(:all_codes, all_codes)

    {:ok, socket, layout: false}
  end

  def handle_event("sort_table", %{"sorter" => sorter}, socket) do
    all_codes = sort_with_nil(socket.assigns.all_codes, sorter)

    socket =
      socket
      |> assign(:all_codes, all_codes)
      |> assign(:active_sorter, sorter)

    {:noreply, socket}
  end

  defp sort_with_nil(elements, sorter) do
    {mapper, direction} =
      case sorter do
        "nlog10p_asc" ->
          {fn row -> row.nlog10p end, :asc}

        "nlog10p_desc" ->
          {fn row -> row.nlog10p end, :desc}

        "odds_ratio_asc" ->
          {fn row -> row.odds_ratio end, :asc}

        "odds_ratio_desc" ->
          {fn row -> row.odds_ratio end, :desc}

        "n_matched_cases_asc" ->
          {fn row -> row.n_matched_cases end, :asc}

        "n_matched_cases_desc" ->
          {fn row -> row.n_matched_cases end, :desc}

        "n_matched_controls_asc" ->
          {fn row -> row.n_matched_controls end, :asc}

        "n_matched_controls_desc" ->
          {fn row -> row.n_matched_controls end, :desc}
      end

    Enum.sort_by(elements, mapper, RisteysWeb.Utils.sorter_nil_end(direction))
  end

  defp to_descriptive_vocabulary(value) do
    case value do
      # TODO(Vincent) Use our abbr/2 function when we figure out a way that
      # the tooltip appears on top of everything when used in a table.
      "ATC" ->
        Phoenix.HTML.Tag.content_tag(:abbr, "ATC",
          title: "Anatomical Therapeutic Chemical Classification System"
        )

      "FHL" ->
        Phoenix.HTML.Tag.content_tag(:abbr, "FHL", title: "Finnish Hospital League")

      _ when value in ["HPN", "HPO"] ->
        Phoenix.HTML.Tag.content_tag(:abbr, "HP", title: "Heart Patients")

      "ICD10fi" ->
        Phoenix.HTML.Tag.content_tag(:span, "ICD-10 Finland", title: "ICD-10 Finland")

      "ICD9fi" ->
        Phoenix.HTML.Tag.content_tag(:span, "ICD-9 Finland", title: "ICD-9 Finland")

      "ICD8fi" ->
        Phoenix.HTML.Tag.content_tag(:span, "ICD-8 Finland", title: "ICD-8 Finland")

      "ICDO3" ->
        "ICD-O-3"

      "ICPC" ->
        Phoenix.HTML.Tag.content_tag(:abbr, "ICPC",
          title: "International Classification of Primary Care"
        )

      "REIMB" ->
        Phoenix.HTML.Tag.content_tag(:span, "Kela drug reimbursment",
          title: "Kela drug reimbursment"
        )

      "SPAT" ->
        Phoenix.HTML.Tag.content_tag(:abbr, "SPAT",
          title: "Finnish primary care outpatient procedures"
        )

      _ ->
        value
    end
  end
end
