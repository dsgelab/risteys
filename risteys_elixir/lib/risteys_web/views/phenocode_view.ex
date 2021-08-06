defmodule RisteysWeb.PhenocodeView do
  use RisteysWeb, :view
  require Integer

  def render("drugs.json", %{drug_stats: drug_stats}) do
    Enum.map(drug_stats, fn drug ->
      ci_min = drug.score - 1.96 * drug.stderr
      ci_max = drug.score + 1.96 * drug.stderr

      %{
        name: drug.description,
        score_num: drug.score,
        score_str: round(drug.score, 2),
        ci_min_num: ci_min,
        ci_min_str: round(ci_min, 2),
        ci_max_num: ci_max,
        ci_max_str: round(ci_max, 2),
        pvalue_num: drug.pvalue,
        pvalue_str: pvalue_str(drug.pvalue),
        n_indivs: drug.n_indivs,
        atc: drug.atc,
        atc_link: atc_link_wikipedia(drug.atc)
      }
    end)
  end

  def render("drugs.csv", %{drug_stats: drug_stats}) do
    header = ~w(ATC name score score_ci_min score_ci_max p N)

    stats =
      Enum.map(drug_stats, fn drug ->
        ci_min = drug.score - 1.96 * drug.stderr
        ci_max = drug.score + 1.96 * drug.stderr

        [drug.atc, drug.description, drug.score, ci_min, ci_max, drug.pvalue, drug.n_indivs]
      end)

    Enum.concat([header], stats)
    |> CSV.encode()
    |> Enum.join()
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

  defp readable_icdver(icd_numbers) do
    icd_numbers
    |> Enum.map(&Integer.to_string/1)
    |> Enum.intersperse(", ")
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

  defp cell_icd10(rule, expanded) do
    max_icds = 10

    if length(expanded) > 0 and length(expanded) <= max_icds do
      render_icds(expanded, true)
    else
      rule
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

  defp relative_count(steps, count) do
    # Compute the percentage of the given count across meaningful steps
    check_steps = MapSet.new([
      :filter_registries,
      :precond_main_mode_icdver,
      :min_number_events,
      :includes
    ])

    max =
      steps
      |> Enum.filter(fn %{name: name} -> name in check_steps end)
      |> Enum.map(fn %{nindivs_post_step: ncases} -> ncases end)
      |> Enum.reject(&is_nil/1)
      |> Enum.max()

    count / max * 100
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

      ahref(source, link)
    end

    ontology = Enum.reject(ontology, fn {_source, ids} -> ids == [] end)

    for {source, ids} <- ontology, into: [] do
      first_id = Enum.at(ids, 0)
      linker.(source, first_id)
    end
  end

  # -- Stats --
  defp distrib_values(distrib) do
    if is_nil(distrib) do
      []
    else
      for [[interval_left, interval_right], val] <- distrib do
        val = if is_nil(val), do: "NaN", else: val

        interval =
          case {interval_left, interval_right} do
            {nil, _} ->
              "up to " <> to_string(interval_right)

            {_, nil} ->
              to_string(interval_left) <> " and up"

            {_, _} ->
              to_string(interval_left) <> "–" <> to_string(interval_right)
          end

        [interval, val]
      end
    end
  end

  defp mortality_table(stats) do
    lags = [
      {0, "1998–2019"},
      {15, "15 years"},
      {5, "5 years"},
      {1, "1 year"}
    ]

    no_data = %{
      absolute_risk: "-",
      hr: "-",
      pvalue: "-",
      n_individuals: "-"
    }

    for {lag, title} <- lags do
      data = Enum.find(stats, fn %{lagged_hr_cut_year: lag_hr} -> lag_hr == lag end)

      stat =
        if not is_nil(data) do
          hr =
            "#{data.hr |> round(2)} [#{data.hr_ci_min |> round(2)}, #{data.hr_ci_max |> round(2)}]"

          %{
            absolute_risk: data.absolute_risk |> round(2),
            hr: hr,
            pvalue: data.pvalue |> pvalue_str(),
            n_individuals: data.n_individuals
          }
        else
          no_data
        end

      {title, stat}
    end
  end

  # -- Helpers --
  defp abbr(text, title) do
    # "data_title" will be converted to "data-title" in HTML
    content_tag(:abbr, text, data_title: title)
  end

  defp icd10_url(text, icd) do
    ahref(text, "https://icd.who.int/browse10/2016/en#/#{icd}")
  end

  defp ahref(text, link) do
    content_tag(:a, text,
      href: link,
      rel: "external nofollow noopener noreferrer",
      target: "_blank"
    )
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

  defp pvalue_str(pvalue) do
    # Print the given pvalue using scientific notation, display
    # "<1e-100" if very low.
    cond do
      is_nil(pvalue) ->
        "-"

      pvalue < 1.0e-100 ->
        "<1e-100"

      true ->
        # See http://erlang.org/doc/man/io.html#format-2
        :io_lib.format("~.2. e", [pvalue]) |> to_string()
    end
  end

  defp atc_link_wikipedia(atc) do
    short = String.slice(atc, 0..2)
    "https://en.wikipedia.org/wiki/ATC_code_#{short}##{atc}"
  end
end
