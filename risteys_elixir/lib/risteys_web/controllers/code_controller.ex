defmodule RisteysWeb.CodeController do
  use RisteysWeb, :controller
  alias Risteys.{Repo, Phenocode}
  import Ecto.Query
  import Phoenix.HTML

  defp data_sources(phenocode) do
    descriptions = [
      omit: "Do NOT RELEASE this endpoint ",
      sex: "SEX specific endpoint",
      conditions: "CONDITIONS required",
      outpat_icd: "Outpatient visit: ICD and other codes ",
      hd_mainonly: "HDR: Only main entry used ",
      hd_icd_10: "HDR: ICD-10 codes",
      hd_icd_9: "HDR: ICD-9 codes",
      hd_icd_8: "HDR: ICD-8 codes",
      hd_icd_10_excl: "HDR: ICD-10 codes to exclude",
      hd_icd_9_excl: "HDR: ICD-9 codes to exclude",
      hd_icd_8_excl: "HDR: ICD-8 codes to exclude",
      cod_mainonly: "C.O.D.: Only main entry used",
      cod_icd_10: "C.O.D.: ICD-10 codes",
      cod_icd_9: "C.O.D.: ICD-9 codes",
      cod_icd_8: "C.O.D.: ICD-8 codes",
      cod_icd_10_excl: "C.O.D.: ICD-10 codes to exclude",
      cod_icd_9_excl: "C.O.D.: ICD-9 codes to exclude",
      cod_icd_8_excl: "C.O.D.: ICD-8 codes to exclude",
      oper_nom: "Operations: NOMESCO codes",
      oper_hl: "Operations: FINNISH HOSPITAL LEAGUE codes",
      oper_hp1: "Operations: HEART PATIENT codes V1",
      oper_hp2: "Operations: HEART PATIENT codes V2",
      kela_reimb: ~E"Reimbursements: <abbr title=\"Finnish Social Insurance Institution\">KELA</abbr> codes",
      kela_reimb_icd: "Reimbursements: ICD codes",
      kela_atc_needother: "Medicine purchases: ATC; other reg. data required",
      kela_atc: "Medicine purchases: ATC codes",
      canc_topo: "Cancer reg: TOPOGRAPHY codes",
      canc_morph: "Cancer reg: MORPHOLOGY codes",
    ]

    descriptions
    |> Enum.map(fn {column, description} ->
      {description, Map.fetch!(phenocode, column)}
    end)
    |> Enum.reject(fn {_description, value} ->
      value in ["", nil, []]
    end)
  end

  def show(conn, %{"phenocode" => code}) do
    phenocode = Repo.one(from p in Phenocode, where: p.code == ^code)

    conn
    |> assign(:code, phenocode.code)
    |> assign(:title, phenocode.longname)
    |> assign(:data_sources, phenocode |> data_sources)
    |> render("show.html")
  end
end
