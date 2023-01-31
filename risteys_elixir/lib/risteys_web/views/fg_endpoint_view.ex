defmodule RisteysWeb.FGEndpointView do
  use RisteysWeb, :view
  require Integer

  alias Risteys.FGEndpoint

  def render("index.json", %{endpoints: endpoints}) do
    endpoints
  end


  def render("assocs.csv", %{assocs: assocs}) do
    header =
      ~w(prior_name outcome_name hr_lag prior_longname outcome_longname hr ci_min ci_max p N)

    assocs =
      Enum.map(assocs, fn assoc ->
        [
          assoc.prior_name,
          assoc.outcome_name,
          assoc.lagged_hr_cut_year,
          assoc.prior_longname,
          assoc.outcome_longname,
          assoc.hr,
          assoc.ci_min,
          assoc.ci_max,
          assoc.pvalue,
          assoc.nindivs
        ]
      end)

    Enum.concat([header], assocs)
    |> CSV.encode()
    |> Enum.join()
  end

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

  defp control_definitions(endpoint) do
    for %{field: field, value: value} <- FGEndpoint.get_control_definitions(endpoint) do
      case field do
        :control_exclude ->
          {
            "Control exclude",
            value
            |> Enum.map(&content_tag(:a, &1, href: &1))
            |> Enum.intersperse(", ")
          }

        :control_preconditions ->
          {"Control pre-conditions", value}

        :control_conditions ->
          conditions =
            value
            |> readable_conditions()
            |> Enum.intersperse(tag("br"))

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
      th = content_tag(:th, rr.title)
      td_value = content_tag(:td, rr.value)
      td_comment = content_tag(:td, rr.comment)

      content_tag(:tr, [th, td_value, td_comment])
    end
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

  defp sort_variants(variants) do
    # Sort variant by CHR, POS.
    Enum.sort_by(variants, fn {variant, _genes} ->
      [chr, pos, _ref, _alt] = String.split(variant, "-")
      chr = String.to_integer(chr)
      pos = String.to_integer(pos)
      [chr, pos]
    end)
  end

  defp list_genes(genes) do
    genes
    |> Enum.map(fn gene -> gene.name end)
    |> Enum.map(fn name -> ahref(name, "https://results.finngen.fi/gene/" <> name) end)
    |> Enum.intersperse(", ")
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
