defmodule RisteysWeb.PhenocodeView do
  use RisteysWeb, :view
  require Integer
  alias Risteys.Phenocode

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

  defp endpoint_def(data_sources, :filter) do
    # Fields we will use for the filter explanation
    map_rule_registries = %{
      # OUTPAT_ICD
      outpat_icd: [:prim_out],
      # HD_
      hd_mainonly: [:inpat, :outpat],
      hd_icd_10_atc: [:inpat, :outpat],
      hd_icd_10s_exp: [:inpat, :outpat],
      hd_icd_10: [:inpat, :outpat],
      hd_icd_9: [:inpat, :outpat],
      hd_icd_8: [:inpat, :outpat],
      hd_icd_10_excl: [:inpat, :outpat],
      hd_icd_9_excl: [:inpat, :outpat],
      hd_icd_8_excl: [:inpat, :outpat],
      # COD_
      cod_mainonly: [:death],
      cod_icd_10: [:death],
      cod_icd_9: [:death],
      cod_icd_8: [:death],
      cod_icd_10_excl: [:death],
      cod_icd_9_excl: [:death],
      cod_icd_8_excl: [:death],
      # OPER_
      oper_nom: [:oper_in, :oper_out],
      oper_hl: [:oper_in, :oper_out],
      oper_hp1: [:oper_in, :oper_out],
      oper_hp2: [:oper_in, :oper_out],
      # KELA_
      kela_reimb: [:purch, :reimb],
      kela_reimb_icd: [:purch, :reimb],
      kela_atc_needother: [:purch, :reimb],
      kela_atc: [:purch, :reimb],
      kela_vnro_needother: [:purch, :reimb],
      kela_vnro: [:purch, :reimb],
      # CANC_
      canc_topo: [:canc],
      canc_topo_excl: [:canc],
      canc_morph: [:canc],
      canc_morph_excl: [:canc],
      canc_behav: [:canc]
    }

    # Regex "$!$" means "no possible matching code", so we mark it as nil
    data_sources =
      Enum.reduce(data_sources, %{}, fn {key, val}, acc ->
        if val == "$!$" do
          Map.put(acc, key, nil)
        else
          Map.put(acc, key, val)
        end
      end)

    # Find which data we use
    rules =
      map_rule_registries
      |> Map.keys()
      |> MapSet.new()

    sources =
      data_sources
      |> Enum.reject(fn {_, val} ->
        case val do
          nil -> true
          [] -> true
          _ -> false
        end
      end)
      |> Keyword.keys()
      |> MapSet.new()

    has_sources = MapSet.intersection(rules, sources)

    # Collect corresponding registries
    used_registries =
      Enum.reduce(has_sources, MapSet.new(), fn source, acc ->
        %{^source => regs} = map_rule_registries
        regs = MapSet.new(regs)
        MapSet.union(acc, regs)
      end)

    # Build registry list in HTML
    reg_html =
      [
        prim_out: %{
          short: "Prim. Out.",
          long: "Avohilmo registry: primary healthcare outpatient visits"
        },
        inpat: %{
          short: "Inpat.",
          long: "Hilmo inpatient registry"
        },
        outpat: %{
          short: "Oupat.",
          long: "Hilmo outpatient registry"
        },
        death: %{
          short: "Death",
          long: "Cause of death registry"
        },
        oper_in: %{
          short: "Oper. in",
          long: "Operations in inpatient Hilmo registry"
        },
        oper_out: %{
          short: "Oper. out",
          long: "Operations in outpatient Hilmo registry"
        },
        purch: %{
          short: "KELA purch.",
          long: "KELA drug purchase registry"
        },
        reimb: %{
          short: "KELA reimb.",
          long: "KELA drug reimbursement registry"
        },
        canc: %{
          short: "Cancer",
          long: "Cancer registry"
        }
      ]
      |> Enum.filter(fn {source, _} -> MapSet.member?(used_registries, source) end)
      |> Enum.map(fn {_, %{short: short, long: long}} -> abbr(short, long) end)
      |> Enum.intersperse(", ")

    {data_sources, reg_html}
  end

  defp endpoint_def(data_sources, :include) do
    if is_nil(data_sources.include) do
      []
    else
      String.split(data_sources.include, "|")
    end
  end

  defp endpoint_def(%{conditions: nil}, :conditions), do: nil

  defp endpoint_def(%{conditions: rule}, :conditions) do
    Phenocode.parse_conditions(rule)
  end

  defp endpoint_def(data_sources, :metadata) do
    tags =
      data_sources.tags
      |> String.split(",")
      |> Enum.join(", ")

    [
      {"Tags", tags},
      {"Level in the ICD hierarchy", data_sources.level},
      {"Special", data_sources.special},
      {"First used in FinnGen datafreeze", data_sources.version},
      {"Parent code in ICD-10", data_sources.parent},
      {"Name in latin", data_sources.latin}
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

  defp mode_info(rule, expanded) do
    is_plural = length(expanded) > 1

    message =
      if is_plural do
        "A case is made only if these codes are the most common among their sibling ICD codes."
      else
        "A case is made only if this code is the most common among its sibling ICD codes."
      end

    if not is_nil(rule) and String.starts_with?(rule, "%") do
      ["(", abbr("mode", message), ")"]
    end
  end

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

  defp distrib_values(distrib) do
    if is_nil(distrib) do
      []
    else
      for [bin, val] <- distrib do
        val = if is_nil(val), do: "NaN", else: val
        [bin, val]
      end
    end
  end

  defp display_correlations(correlations) do
    correlations
    |> Enum.with_index()
    |> Enum.map(fn {corr, idx} ->
      case_ratio =
        case corr.case_ratio do
          nil -> "-"
          val -> round(val * 100, 2)
        end

      gws_hits = if is_nil(corr.gws_hits), do: "-", else: corr.gws_hits

      coloc_gws_hits_same_dir =
        case corr.coloc_gws_hits_same_dir do
          nil -> "-"
          val -> val
        end

      coloc_gws_hits_opp_dir =
        case corr.coloc_gws_hits_opp_dir do
          nil -> "-"
          val -> val
        end

      rel_beta = if is_nil(corr.rel_beta), do: "-", else: corr.rel_beta

      corr = %{
        corr
        | case_ratio: case_ratio,
          gws_hits: gws_hits,
          coloc_gws_hits_same_dir: coloc_gws_hits_same_dir,
          coloc_gws_hits_opp_dir: coloc_gws_hits_opp_dir,
          rel_beta: rel_beta
      }

      bg_color =
        if Integer.mod(idx, 2) == 0 do
          "bg-white"
        else
          "bg-grey-lightest"
        end

      Map.put(corr, :bg_color, bg_color)
    end)
  end

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
end
