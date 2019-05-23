defmodule RisteysWeb.PhenocodeView do
  use RisteysWeb, :view

  defp sorted_descriptions(descriptions) do
    Enum.sort(descriptions, fn a, b -> String.length(a) > String.length(b) end)
  end

  defp table_data_sources(data_sources) do
    # Merge HD registry ICDs
    hd_icd10s = render_icds("ICD-10: ", data_sources.hd_icd10s)
    hd_icd9s = render_icds("ICD-9: ", data_sources.hd_icd9s)

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
    cod_icd10s = render_icds("ICD-10: ", data_sources.cod_icd10s)
    cod_icd9s = render_icds("ICD-9: ", data_sources.cod_icd9s)

    cod_icd8s =
      if not is_nil(data_sources.cod_icd8s) do
        "ICD-8: " <> data_sources.cod_icd8s
      else
        ""
      end

    cod = [cod_icd10s, cod_icd9s, cod_icd8s]
    cod = Enum.reject(cod, fn val -> val == "" end)
    cod = Enum.intersperse(cod, ", ")

    kela_icd10s = render_icds("ICD-10: ", data_sources.kela_icd10s)

    # Build the whole table
    kela_abbr = abbr("KELA", "Finnish Social Insurance Institution")

    table = [
      {"Hospital Discharge registry", hd},
      {"Cause of Death registry", cod},
      {[kela_abbr | " reimbursements"], kela_icd10s},
      {"Outpatient visit: ICD and other codes ", data_sources.outpat_icd},
      {"Operations: NOMESCO codes", data_sources.oper_nom},
      {"Operations: FINNISH HOSPITAL LEAGUE codes", data_sources.oper_hl},
      {"Operations: HEART PATIENT codes V1", data_sources.oper_hp1},
      {"Operations: HEART PATIENT codes V2", data_sources.oper_hp2},
      {[kela_abbr | " reimboursements codes"], data_sources.kela_reimb},
      {"Medicine purchases: ATC; other reg. data required", data_sources.kela_atc_needother},
      {"Medicine purchases: ATC codes", data_sources.kela_atc},
      {"Cancer reg: TOPOGRAPHY codes", data_sources.canc_topo},
      {"Cancer reg: MORPHOLOGY codes", data_sources.canc_morph},
      {"Do NOT RELEASE this endpoint ", data_sources.omit},
      {"SEX specific endpoint", data_sources.sex},
      {"CONDITIONS required", data_sources.conditions}
    ]

    # Discard table rows with no values
    Enum.reject(table, fn {_name, values} -> values in ["", nil, []] end)
  end

  defp render_icds(_prefix, nil), do: ""
  defp render_icds(_prefix, []), do: ""

  defp render_icds(prefix, icds) do
    icds =
      icds
      |> Enum.map(fn icd -> abbr(icd.code, icd.description) end)
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
      "EFO_CLEAN" => %{
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

  defp ahref(text, link) do
    content_tag(:a, text,
      href: link,
      rel: "external nofollow noopener noreferrer",
      target: "_blank"
    )
  end

  defp round(number, precision) do
    case number do
      "N/A" -> "N/A"
      _ -> Float.round(number, precision)
    end
  end

  defp percentage(number) do
    case number do
      "N/A" ->
	"N/A"

      _ ->
	number * 100
    end
  end
end
