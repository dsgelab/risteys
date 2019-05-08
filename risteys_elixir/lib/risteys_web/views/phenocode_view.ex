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
    Enum.reject(table, fn {_name, values} -> values in ["", nil, ["", "", ""]] end)
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
    for {source, values} <- ontology, into: %{} do
      values = Enum.intersperse(values, ", ")
      {source, values}
    end
  end

  defp abbr(text, title) do
    content_tag(:abbr, text, [{:data, [title: title]}])
  end

  defp round(number, precision) do
    case number do
      "N/A" -> "N/A"
      _ -> Float.round(number, precision)
    end
  end
end
