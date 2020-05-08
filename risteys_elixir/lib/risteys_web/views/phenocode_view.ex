defmodule RisteysWeb.PhenocodeView do
  use RisteysWeb, :view
  require Integer

  def render("assocs.json", %{phenocode: phenocode, assocs: assocs}) do
    %{
      "plot" => data_assocs_plot(phenocode, assocs),
      "table" => data_assocs_table(phenocode.id, assocs)
    }
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

  defp table_ontology(ontology) do
    display = %{
      "DOID" => %{
        display: "DOID",
        url: fn doid ->
          link = "https://www.ebi.ac.uk/ols/search?q=" <> doid <> "&ontology=doid"
          ahref(doid, link)
        end
      },
      "EFO" => %{
        display: "GWAS catalog",
        url: fn efo ->
          link = "https://www.ebi.ac.uk/gwas/efotraits/EFO_" <> efo
          ahref(efo, link)
        end
      },
      "MESH" => %{
        display: "MESH",
        url: fn mesh ->
          link = "https://meshb.nlm.nih.gov/record/ui?ui=" <> mesh
          ahref(mesh, link)
        end
      },
      "SNOMED" => %{
        display: "SNOMED CT",
        url: fn snomed ->
          link =
            "https://browser.ihtsdotools.org/?perspective=full&conceptId1=" <>
              snomed <> "&edition=en-edition"

          ahref(snomed, link)
        end
      }
    }

    table =
      for {source, values} <- ontology, into: %{} do
        values =
          Enum.map(values, fn id ->
            fun =
              display
              |> Map.fetch!(source)
              |> Map.fetch!(:url)

            fun.(id)
          end)

        source =
          display
          |> Map.fetch!(source)
          |> Map.fetch!(:display)

        values = Enum.intersperse(values, ", ")

        {source, values}
      end

    Enum.reject(table, fn {_name, values} -> values == [] end)
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
    content_tag(:abbr, text, [{:data, [title: title]}])
  end

  defp icd10_url(text, icd) do
    # ICD browser uses X12.3 instead of X1234
    short = String.slice(icd, 0..3)
    {prefix, suffix} = String.split_at(short, 3)
    icd = prefix <> "." <> suffix

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

  defp data_assocs_plot(phenocode, assocs) do
    assocs
    |> Enum.filter(fn %{lagged_hr_cut_year: cut} ->
      cut == 0  # keep only non-lagged HR on plot
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
        "hr" => round(assoc.hr, 2),
        "ci_min" => round(assoc.ci_min, 2),
        "ci_max" => round(assoc.ci_max, 2),
        "pvalue_str" => pvalue_str(assoc.pvalue),
        "pvalue_num" => assoc.pvalue,
        "nindivs" => assoc.nindivs
      }
    end)
  end

  defp data_assocs_table(pheno_id, assocs) do
    # Takes the associations from the database and transform them to
    # values for the assocation table, such that each table row has
    # "before" and "after" associations with the given pheno_id.
    no_stats = %{
      "hr" => nil,
      "ci_min" => nil,
      "ci_max" => nil,
      "pvalue" => nil,
      "nindivs" => nil,
      "lagged_hr_cut_year" => nil
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
      "hr" => round(assoc.hr, 2),
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
