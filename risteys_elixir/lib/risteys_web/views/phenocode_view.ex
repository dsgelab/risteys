defmodule RisteysWeb.PhenocodeView do
  use RisteysWeb, :view
  require Integer

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

  defp table_data_sources(data_sources) do
    # Merge HD registry ICDs
    hd_icd10s = render_icds("ICD-10: ", data_sources.hd_icd10s, true)
    hd_icd9s = render_icds("ICD-9: ", data_sources.hd_icd9s, false)

    hd_icd8s =
      if not is_nil(data_sources.hd_icd8s) do
        "ICD-8: " <> data_sources.hd_icd8s
      else
        ""
      end

    hd = [hd_icd10s, hd_icd9s, hd_icd8s]
    hd = Enum.reject(hd, fn val -> val == "" end)
    hd = Enum.intersperse(hd, ", ")

    # Merge COD registry ICDs
    cod_icd10s = render_icds("ICD-10: ", data_sources.cod_icd10s, true)
    cod_icd9s = render_icds("ICD-9: ", data_sources.cod_icd9s, false)

    cod_icd8s =
      if not is_nil(data_sources.cod_icd8s) do
        "ICD-8: " <> data_sources.cod_icd8s
      else
        ""
      end

    cod = [cod_icd10s, cod_icd9s, cod_icd8s]
    cod = Enum.reject(cod, fn val -> val == "" end)
    cod = Enum.intersperse(cod, ", ")

    kela_icd10s = render_icds("ICD-10: ", data_sources.kela_icd10s, true)

    # Link to included phenocodes
    include =
      if not is_nil(data_sources.include) do
        data_sources.include
        |> String.split("|")
        |> Enum.map(fn name -> content_tag(:a, name, href: name) end)
        |> Enum.intersperse(", ")
      end

    # Build the whole table
    kela_abbr = abbr("KELA", "Finnish Social Insurance Institution")

    table = [
      {"Hospital Discharge registry", hd},
      {"Hospital Discharge registry: exclude ICD-10", data_sources.hd_icd10s_excl},
      {"Hospital Discharge registry: exclude ICD-9", data_sources.hd_icd9s_excl},
      {"Hospital Discharge registry: exclude ICD-8", data_sources.hd_icd8s_excl},
      {"Hospital Discharge registry: only main entry used", data_sources.hd_mainonly},
      {"Hospital Discharge: ATC drug used", data_sources.hd_icd_10_atc},
      {"Cause of Death registry", cod},
      {"Cause of Death registry: exclude ICD-10", data_sources.cod_icd10s_excl},
      {"Cause of Death registry: exclude ICD-9", data_sources.cod_icd9s_excl},
      {"Cause of Death registry: exclude ICD-8", data_sources.cod_icd8s_excl},
      {"Cause of Death registry: only main entry used", data_sources.cod_mainonly},
      {"Outpatient visit: ICD and other codes ", data_sources.outpat_icd},
      {"Operations: NOMESCO codes", data_sources.oper_nom},
      {"Operations: FINNISH HOSPITAL LEAGUE codes", data_sources.oper_hl},
      {"Operations: HEART PATIENT codes V1", data_sources.oper_hp1},
      {"Operations: HEART PATIENT codes V2", data_sources.oper_hp2},
      {[kela_abbr | " reimboursements codes"], data_sources.kela_reimb},
      {[kela_abbr | " reimbursements"], kela_icd10s},
      {"Medicine purchases: ATC; other reg. data required", data_sources.kela_atc_needother},
      {"Medicine purchases: ATC codes", data_sources.kela_atc},
      {"Cancer reg: TOPOGRAPHY codes", data_sources.canc_topo},
      {"Cancer reg: MORPHOLOGY codes", data_sources.canc_morph},
      {"Sex specific endpoint", data_sources.sex},
      {"Pre-conditions required", data_sources.pre_conditions},
      {"Conditions required", data_sources.conditions},
      {"Include", include},
      {"Level in the ICD-hierarchy", data_sources.level},
      {"First defined in version", data_sources.version},
      {"Latin name", data_sources.latin}
    ]

    # Discard table rows with no values
    Enum.reject(table, fn {_name, values} -> values in ["", nil, []] end)
  end

  defp render_icds(_prefix, nil, _url), do: ""
  defp render_icds(_prefix, [], _url), do: ""

  defp render_icds(prefix, icds, url?) do
    icds =
      icds
      |> Enum.map(fn icd ->
        text = abbr(icd.code, icd.description)

        if url? do
          icd10_url(text, icd.code)
        else
          text
        end
      end)
      |> Enum.intersperse("/")

    [prefix | icds]
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

  defp abbr(text, title) do
    content_tag(:abbr, text, title: title)
  end

  defp icd10_url(text, icd) do
    # ICD browser uses X12.3 instead of X1234
    short = String.slice(icd, 0..3)

    icd =
      case String.split_at(short, 3) do
        {prefix, ""} ->
          prefix

        {prefix, suffix} ->
          prefix <> "." <> suffix
      end

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
      # Values for CompBox plot
      "hr_norm" => nil,
      "hr_norm_min" => nil,
      "hr_norm_max" => nil,
      "hr_norm_lop" => nil,
      "hr_norm_q1" => nil,
      "hr_norm_median" => nil,
      "hr_norm_q3" => nil,
      "hr_norm_hip" => nil
    }

    no_hr_norm_stats = %{
      hr: nil,
      lop: nil,
      q1: nil,
      median: nil,
      q3: nil,
      hip: nil
    }

    %{
      distribs: prior_distribs,
      min: prior_min,
      max: prior_max
    } = hr_prior_distribs

    %{
      distribs: outcome_distribs,
      min: outcome_min,
      max: outcome_max
    } = hr_outcome_distribs

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
            hr_stats = Map.get(prior_distribs, other_id, no_hr_norm_stats)

            Map.merge(
              stats,
              %{
                "hr_norm" => hr_stats.hr,
                "hr_norm_min" => prior_min,
                "hr_norm_max" => prior_max,
                "hr_norm_lop" => hr_stats.lop,
                "hr_norm_q1" => hr_stats.q1,
                "hr_norm_median" => hr_stats.median,
                "hr_norm_q3" => hr_stats.q3,
                "hr_norm_hip" => hr_stats.hip
              }
            )
        end

      no_lag_after =
        case get_in(lag_data, [0, "after"]) do
          nil ->
            no_stats

          stats ->
            hr_stats = Map.get(outcome_distribs, other_id, no_hr_norm_stats)

            Map.merge(
              stats,
              %{
                "hr_norm" => hr_stats.hr,
                "hr_norm_min" => outcome_min,
                "hr_norm_max" => outcome_max,
                "hr_norm_lop" => hr_stats.lop,
                "hr_norm_q1" => hr_stats.q1,
                "hr_norm_median" => hr_stats.median,
                "hr_norm_q3" => hr_stats.q3,
                "hr_norm_hip" => hr_stats.hip
              }
            )
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
      "nindivs" => assoc.nindivs
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
