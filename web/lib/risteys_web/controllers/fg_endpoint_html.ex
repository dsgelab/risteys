defmodule RisteysWeb.FGEndpointHTML do
  use RisteysWeb, :html

  embed_templates "fg_endpoint_html/*"

  # -- Summary Statistics --
  defp gen_histogram(endpoint, variable, dataset) do
    variable_str = Atom.to_string(variable)
    dataset_str = Atom.to_string(dataset)
    id = "bin-plot-#{variable_str}-#{dataset_str}"

    x_label =
      case variable do
        :age -> "Age"
        :year -> "Year"
      end

    y_label = "Individuals"

    bar_color =
      case dataset do
        :finregistry -> "#14b8a6"
        :finngen -> "#22292F"
      end

    values =
      case {variable, dataset} do
        {:age, :finregistry} ->
          Risteys.FGEndpoint.get_age_histogram(endpoint.name, "FR")

        {:year, :finregistry} ->
          Risteys.FGEndpoint.get_year_histogram(endpoint.name, "FR")

        {:age, :finngen} ->
          Risteys.FGEndpoint.get_age_histogram(endpoint.name, "FG")

        {:year, :finngen} ->
          Risteys.FGEndpoint.get_year_histogram(endpoint.name, "FG")
      end

    gen_div_histogram(id, x_label, y_label, bar_color, values)
  end

  defp gen_div_histogram(id, x_label, y_label, bar_color, values) do
    Phoenix.HTML.Tag.content_tag(
      :div,
      "",
      # NOTE[D3SELECT] Setting the id is necessary has the downstream d3.select only accepts a string selector and not a node %>
      id: id,
      data_histogram_x_axis_label: x_label,
      data_histogram_y_axis_label: y_label,
      data_histogram_plot_bar_color: bar_color,
      data_histogram_values: Jason.encode!(values)
    )
  end

  defp gen_cif_plot(endpoint, dataset) do
    dataset_db =
      case dataset do
        :finregistry -> "FR"
        :finngen -> "FG"
      end

    cif_plot_data =
      Risteys.FGEndpoint.get_cumulative_incidence_plot_data(endpoint.name, dataset_db)

    any_data? = (not Enum.empty?(cif_plot_data.females)) or (not Enum.empty?(cif_plot_data.males))

    content =
      if any_data? do
        ""
      else
        "No data"
      end

    dataset_str = Atom.to_string(dataset)
    id = "cumulinc-plot-#{dataset_str}"

    female_color =
      case dataset do
        :finregistry -> "#14b8a6"
        :finngen -> "#3490DC"
      end

    payload =
      if any_data? do
        [
          %{
            name: "female",
            color: female_color,
            dasharray: "1 0",
            cumulinc: cif_plot_data.females,
            max_value: cif_plot_data.max_value
          },
          %{
            name: "male",
            color: "#22292F",
            dasharray: "9 1",
            cumulinc: cif_plot_data.males,
            max_value: cif_plot_data.max_value
          }
        ]
      else
        []
      end

    Phoenix.HTML.Tag.content_tag(
      :div,
      content,
      # See NOTE[D3SELECT]
      id: id,
      data_cif_data: Jason.encode!(payload)
    )
  end

  # -- Ontology --
  defp ontology_links(ontology) do
    # Helper function to link to external resources
    linker = fn source, id ->
      link =
        case source do
          "DOID" ->
            "https://www.ebi.ac.uk/ols/search?q=" <> id <> "&ontology=doid"

          "EFO" ->
            "https://www.ebi.ac.uk/gwas/efotraits/EFO_" <> id

          "MESH" ->
            "https://meshb.nlm.nih.gov/record/ui?ui=" <> id

          "SNOMED" ->
            "https://browser.ihtsdotools.org/?perspective=full&conceptId1=" <>
              id <> "&edition=en-edition"
        end

      ahref_extern(link, source)
    end

    ontology = Enum.reject(ontology, fn {_source, ids} -> ids == [] end)

    for {source, ids} <- ontology, into: [] do
      first_id = Enum.at(ids, 0)
      linker.(source, first_id)
    end
  end

  # -- Endpoint Explainer --
  defp get_explainer_step(steps, name) do
    # Get a step by name
    Enum.find(steps, fn %{name: step_name} -> step_name == name end)
  end

  defp readable_conditions(conditions) do
    Enum.map(conditions, fn condition ->
      condition
      |> String.replace("!", "not ")
      |> String.replace("_NEVT", "number of events ")
      |> String.replace("&", "and ")
      |> String.replace("|", "or ")
    end)
  end

  defp control_definitions(endpoint) do
    for %{field: field, value: value} <- Risteys.FGEndpoint.get_control_definitions(endpoint) do
      case field do
        :control_exclude ->
          {
            "Control exclude",
            value
            |> Enum.map(&Phoenix.HTML.Tag.content_tag(:a, &1, href: &1))
            |> Enum.intersperse(", ")
          }

        :control_preconditions ->
          {"Control pre-conditions", value}

        :control_conditions ->
          conditions =
            value
            |> readable_conditions()
            |> Enum.intersperse(Phoenix.HTML.Tag.tag("br"))

          {"Control conditions", conditions}
      end
    end
  end

  defp readable_metadata(endpoint) do
    [
      {"Level in the ICD hierarchy", endpoint.level},
      {"Special", endpoint.special},
      {"First used in FinnGen datafreeze", endpoint.version},
      {"Parent code in ICD-10", endpoint.parent},
      {"Name in latin", endpoint.latin}
    ]
    |> Enum.reject(fn {_col, val} -> is_nil(val) end)
  end

  defp cell_icd10(filter, key_orig_rule, key_expanded) do
    if Map.has_key?(filter, key_expanded) do
      %{
        ^key_orig_rule => orig_rule,
        ^key_expanded => expanded_rule
      } = filter

      max_icds = 10

      if length(expanded_rule) > 0 and length(expanded_rule) <= max_icds do
        render_icds(expanded_rule, true)
      else
        orig_rule
      end
    else
      filter[key_orig_rule]
    end
  end

  defp render_icds([], _url), do: ""

  defp render_icds(icds, url?) do
    icds
    |> Enum.sort()
    |> Enum.map(fn icd ->
      content =
        if url? do
          icd10_url(icd.code, icd.code)
        else
          icd.code
        end

      abbr(content, icd.description)
    end)
    |> Enum.intersperse(", ")
  end

  defp icd10_url(text, icd) do
    ahref_extern("https://icd.who.int/browse10/2016/en#/#{icd}", text)
  end

  defp rows_original_rules(endpoint) do
    rows = [
      %{title: "NAME", value: endpoint.name},
      %{title: "CONTROL_EXCLUDE", value: endpoint.control_exclude},
      %{title: "CONTROL_PRECONDITIONS", value: endpoint.control_preconditions},
      %{title: "CONTROL_CONDITIONS", value: endpoint.control_conditions},
      %{title: "SEX", value: endpoint.sex},
      %{title: "INCLUDE", value: endpoint.include},
      %{title: "PRE_CONDITIONS", value: endpoint.pre_conditions},
      %{title: "CONDITIONS", value: endpoint.conditions},
      %{title: "OUTPAT_ICD", value: endpoint.outpat_icd},
      %{title: "OUTPAT_OPER", value: endpoint.outpat_oper},
      %{title: "HD_MAINONLY", value: endpoint.hd_mainonly},
      %{title: "HD_ICD_10_ATC", value: endpoint.hd_icd_10_atc},
      %{title: "HD_ICD_10", value: endpoint.hd_icd_10},
      %{title: "HD_ICD_9", value: endpoint.hd_icd_9},
      %{title: "HD_ICD_8", value: endpoint.hd_icd_8},
      %{title: "HD_ICD_10_EXCL", value: endpoint.hd_icd_10_excl},
      %{title: "HD_ICD_9_EXCL", value: endpoint.hd_icd_9_excl},
      %{title: "HD_ICD_8_EXCL", value: endpoint.hd_icd_8_excl},
      %{title: "COD_MAINONLY", value: endpoint.cod_mainonly},
      %{title: "COD_ICD_10", value: endpoint.cod_icd_10},
      %{title: "COD_ICD_9", value: endpoint.cod_icd_9},
      %{title: "COD_ICD_8", value: endpoint.cod_icd_8},
      %{title: "COD_ICD_10_EXCL", value: endpoint.cod_icd_10_excl},
      %{title: "COD_ICD_9_EXCL", value: endpoint.cod_icd_9_excl},
      %{title: "COD_ICD_8_EXCL", value: endpoint.cod_icd_8_excl},
      %{title: "OPER_NOM", value: endpoint.oper_nom},
      %{title: "OPER_HL", value: endpoint.oper_hl},
      %{title: "OPER_HP1", value: endpoint.oper_hp1},
      %{title: "OPER_HP2", value: endpoint.oper_hp2},
      %{title: "KELA_REIMB", value: endpoint.kela_reimb},
      %{title: "KELA_REIMB_ICD", value: endpoint.kela_reimb_icd},
      %{title: "KELA_ATC_NEEDOTHER", value: endpoint.kela_atc_needother},
      %{title: "KELA_ATC", value: endpoint.kela_atc},
      %{title: "KELA_VNRO_NEEDOTHER", value: endpoint.kela_vnro_needother},
      %{title: "KELA_VNRO", value: endpoint.kela_vnro},
      %{title: "CANC_TOPO", value: endpoint.canc_topo},
      %{title: "CANC_TOPO_EXCL", value: endpoint.canc_topo_excl},
      %{title: "CANC_MORPH", value: endpoint.canc_morph},
      %{title: "CANC_MORPH_EXCL", value: endpoint.canc_morph_excl},
      %{title: "CANC_BEHAV", value: endpoint.canc_behav}
    ]

    rows =
      for rr <- rows do
        comment =
          case rr.value do
            "$!$" ->
              "The FinnGen clinical team has checked and no code can be used for this rule."

            _ ->
              ""
          end

        Map.put_new(rr, :comment, comment)
      end

    for rr <- rows do
      th = Phoenix.HTML.Tag.content_tag(:th, rr.title)
      td_value = Phoenix.HTML.Tag.content_tag(:td, rr.value)
      td_comment = Phoenix.HTML.Tag.content_tag(:td, rr.comment)

      Phoenix.HTML.Tag.content_tag(:tr, [th, td_value, td_comment])
    end
  end

  def any_mortality_data?(data, sex) do
    coef =
      data
      |> Map.fetch!(sex)
      |> Map.fetch!(:exposure)
      |> Map.fetch!(:coef)

    cases =
      data
      |> Map.fetch!(sex)
      |> Map.fetch!(:case_counts)
      |> Map.fetch!(:exposed_cases)

    not is_nil(coef) and not is_nil(cases)
  end

  def get_HR_and_CIs(data, sex, stat_name) do
    stats = data |> Map.fetch!(sex) |> Map.fetch!(stat_name)

    if is_nil(stats.coef) or is_nil(stats.ci95_lower) or is_nil(stats.ci95_upper) do
      "No data"
    else
      format_HR_and_CIs(stats.coef, stats.ci95_lower, stats.ci95_upper)
    end
  end

  defp format_HR_and_CIs(hr, ci_lower, ci_upper) do
    exp_hr = :math.exp(hr) |> Float.round(3) |> Float.to_string()
    exp_ci_lower = :math.exp(ci_lower) |> Float.round(2) |> Float.to_string()
    exp_ci_upper = :math.exp(ci_upper) |> Float.round(2) |> Float.to_string()

    "#{exp_hr} [#{exp_ci_lower}, #{exp_ci_upper}]"
  end

  def show_p(data, sex, stat_name) do
    stat_value = data |> Map.fetch!(sex) |> Map.fetch!(stat_name) |> Map.fetch!(:p_value)

    cond do
      is_nil(stat_value) ->
        "No data"

      stat_value < 0.001 ->
        "< 0.001"

      true ->
        stat_value |> Float.round(3) |> Float.to_string()
    end
  end

  # -- Helpers --
  defp abbr(text, title) do
    # "data_title" will be converted to "data-title" in HTML
    Phoenix.HTML.Tag.content_tag(:abbr, text, data_title: title)
  end

  defp round(number, precision) do
    case number do
      "-" -> "-"
      _ -> :io_lib.format("~.#{precision}. f", [number]) |> to_string()
    end
  end

  defp percentage(number) do
    case number do
      "-" ->
        "-"

      nil ->
        "-"

      _ ->
        number * 100
    end
  end
end
