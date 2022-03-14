defmodule RisteysWeb.PhenocodeView do
  use RisteysWeb, :view
  require Integer

  alias Risteys.FGEndpoint

  def render("assocs.json", %{
        phenocode: phenocode,
        assocs: assocs,
        hr_prior_distribs: hr_prior_distribs,
        hr_outcome_distribs: hr_outcome_distribs
      }) do
    %{
      "plot" => data_assocs_plot(phenocode, assocs),
      "table" => data_assocs_table(phenocode.id, assocs, hr_prior_distribs, hr_outcome_distribs)
    }
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

  defp relative_count(steps, count) do
    # Compute the percentage of the given count across meaningful steps
    check_steps =
      MapSet.new([
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

    if max != 0 do
      count / max * 100

    else
      # If there is no data then max will be 0 but we can't divide by 0.
      # So we handle this corner case by returning 0, which will
      # effectively set the bar width to 0 in the endpoint explainer flow.
      0
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

  defp data_assocs_plot(phenocode, assocs) do
    assocs
    |> Enum.filter(fn %{lagged_hr_cut_year: cut} ->
      # keep only non-lagged HR on plot
      cut == 0
    end)
    |> Enum.map(fn assoc ->
      # Find direction given phenocode of interest
      {other_pheno_name, other_pheno_longname, other_pheno_category, direction} =
        if phenocode.name == assoc.prior_name do
          {assoc.outcome_name, assoc.outcome_longname, assoc.outcome_category, "after"}
        else
          {assoc.prior_name, assoc.prior_longname, assoc.prior_category, "before"}
        end

      %{
        "name" => other_pheno_name,
        "longname" => other_pheno_longname,
        "category" => other_pheno_category,
        "direction" => direction,
        "hr" => assoc.hr,
        "hr_str" => round(assoc.hr, 2),
        "ci_min" => round(assoc.ci_min, 2),
        "ci_max" => round(assoc.ci_max, 2),
        "pvalue_str" => pvalue_str(assoc.pvalue),
        "pvalue_num" => assoc.pvalue,
        "nindivs" => assoc.nindivs
      }
    end)
  end

  defp data_assocs_table(pheno_id, assocs, hr_prior_distribs, hr_outcome_distribs) do
    # Merge binned HR distrib in assocs table
    binned_prior_hrs =
      for bin <- hr_prior_distribs, into: %{}, do: {bin.pheno_id, bin.percent_rank}

    binned_outcome_hrs =
      for bin <- hr_outcome_distribs, into: %{}, do: {bin.pheno_id, bin.percent_rank}

    assocs =
      Enum.map(
        assocs,
        fn assoc ->
          if assoc.outcome_id == pheno_id do
            hr_binned = Map.get(binned_prior_hrs, assoc.prior_id)
            Map.put(assoc, :hr_binned, hr_binned)
          else
            hr_binned = Map.get(binned_outcome_hrs, assoc.outcome_id)
            Map.put(assoc, :hr_binned, hr_binned)
          end
        end
      )

    # Takes the associations from the database and transform them to
    # values for the assocation table, such that each table row has
    # "before" and "after" associations with the given pheno_id.
    no_stats = %{
      "hr" => nil,
      "hr_str" => nil,
      "ci_min" => nil,
      "ci_max" => nil,
      "pvalue" => nil,
      "nindivs" => nil,
      "lagged_hr_cut_year" => nil,
      # value for CompBox plot
      "hr_binned" => nil
    }

    rows =
      Enum.reduce(assocs, %{}, fn assoc, acc ->
        to_record(acc, assoc, pheno_id)
      end)

    Enum.map(rows, fn {other_id, lag_data} ->
      no_lag_before =
        case get_in(lag_data, [0, "before"]) do
          nil ->
            no_stats

          stats ->
            stats
        end

      no_lag_after =
        case get_in(lag_data, [0, "after"]) do
          nil ->
            no_stats

          stats ->
            stats
        end

      lag_1y_before =
        case get_in(lag_data, [1, "before"]) do
          nil ->
            no_stats

          stats ->
            stats
        end

      lag_1y_after =
        case get_in(lag_data, [1, "after"]) do
          nil ->
            no_stats

          stats ->
            stats
        end

      lag_5y_before =
        case get_in(lag_data, [5, "before"]) do
          nil ->
            no_stats

          stats ->
            stats
        end

      lag_5y_after =
        case get_in(lag_data, [5, "after"]) do
          nil ->
            no_stats

          stats ->
            stats
        end

      lag_15y_before =
        case get_in(lag_data, [15, "before"]) do
          nil ->
            no_stats

          stats ->
            stats
        end

      lag_15y_after =
        case get_in(lag_data, [15, "after"]) do
          nil ->
            no_stats

          stats ->
            stats
        end

      %{
        "id" => other_id,
        "name" => lag_data["name"],
        "longname" => lag_data["longname"],
        "all" => %{
          "before" => no_lag_before,
          "after" => no_lag_after
        },
        "lagged_1y" => %{
          "before" => lag_1y_before,
          "after" => lag_1y_after
        },
        "lagged_5y" => %{
          "before" => lag_5y_before,
          "after" => lag_5y_after
        },
        "lagged_15y" => %{
          "before" => lag_15y_before,
          "after" => lag_15y_after
        }
      }
    end)
  end

  defp to_record(res, assoc, pheno_id) do
    # Takes an association and transform it to a suitable value for a
    # row in the association table.
    [dir, other_pheno] =
      if pheno_id == assoc.prior_id do
        [
          "after",
          %{
            id: assoc.outcome_id,
            name: assoc.outcome_name,
            longname: assoc.outcome_longname
          }
        ]
      else
        [
          "before",
          %{
            id: assoc.prior_id,
            name: assoc.prior_name,
            longname: assoc.prior_longname
          }
        ]
      end

    lag = assoc.lagged_hr_cut_year

    new_stats = %{
      "hr" => assoc.hr,
      "hr_str" => round(assoc.hr, 2),
      "ci_min" => round(assoc.ci_min, 2),
      "ci_max" => round(assoc.ci_max, 2),
      "pvalue" => assoc.pvalue,
      "pvalue_str" => pvalue_str(assoc.pvalue),
      "nindivs" => assoc.nindivs,
      "hr_binned" => assoc.hr_binned
    }

    # Create pheno mapping if not existing
    res =
      if is_nil(Map.get(res, other_pheno.id)) do
        Map.put(res, other_pheno.id, %{})
      else
        res
      end

    # Create inner lag mapping if not existing
    res =
      if is_nil(get_in(res, [other_pheno.id, lag])) do
        put_in(res, [other_pheno.id, lag], %{})
      else
        res
      end

    res
    |> put_in([other_pheno.id, lag, dir], new_stats)
    |> put_in([other_pheno.id, "name"], other_pheno.name)
    |> put_in([other_pheno.id, "longname"], other_pheno.longname)
  end

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
