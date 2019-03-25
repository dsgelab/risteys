defmodule RisteysWeb.CodeController do
  use RisteysWeb, :controller
  alias Risteys.{Repo, ICD10, Phenocode}
  import Ecto.Query
  import Phoenix.HTML

  def show(conn, %{"phenocode" => code}) do
    phenocode = Repo.one(from p in Phenocode, where: p.code == ^code)

    icd10s =
      (phenocode.hd_icd_10 ++ phenocode.cod_icd_10 ++ phenocode.kela_reimb_icd)
      |> MapSet.new()

    icd10s =
      for icd <- icd10s, into: %{} do
        description = Repo.one(from i in ICD10, where: i.code == ^icd, select: i.description)
        {icd, description}
      end

    conn
    |> assign(:code, phenocode.code)
    |> assign(:title, phenocode.longname)
    |> assign(:data_sources, data_sources(phenocode, icd10s))
    |> render("show.html")
  end

  defp data_sources(phenocode, icd10s) do
    descriptions = [
      omit: "Do NOT RELEASE this endpoint ",
      sex: "SEX specific endpoint",
      conditions: "CONDITIONS required",
      outpat_icd: "Outpatient visit: ICD and other codes ",
      oper_nom: "Operations: NOMESCO codes",
      oper_hl: "Operations: FINNISH HOSPITAL LEAGUE codes",
      oper_hp1: "Operations: HEART PATIENT codes V1",
      oper_hp2: "Operations: HEART PATIENT codes V2",
      kela_reimb:
        ~E"Reimbursements: <abbr title=\"Finnish Social Insurance Institution\">KELA</abbr> codes",
      kela_reimb_icd: "Reimbursements: ICD codes",
      kela_atc_needother: "Medicine purchases: ATC; other reg. data required",
      kela_atc: "Medicine purchases: ATC codes",
      canc_topo: "Cancer reg: TOPOGRAPHY codes",
      canc_morph: "Cancer reg: MORPHOLOGY codes"
    ]

    hd_icd_10 =
      phenocode.hd_icd_10
      |> Enum.map(&abbr_icd10(&1, icd10s))
    hd_codes = hd_icd_10 ++ [phenocode.hd_icd_9] ++ [phenocode.hd_icd_8]

    cod_icd_10 =
      phenocode.cod_icd_10
      |> Enum.map(&abbr_icd10(&1, icd10s))
    cod_codes = cod_icd_10 ++ [phenocode.cod_icd_9] ++ [phenocode.cod_icd_8]

    data_table =
      descriptions
      |> Enum.map(fn {column, description} ->
        {description, Map.fetch!(phenocode, column)}
      end)

    (data_table ++
       [{"Hospital Discharge registry", hd_codes}, {"Cause of death registry", cod_codes}])
    |> Enum.reject(fn {_description, value} ->
      value in ["", nil, []]
    end)
  end

  defp abbr_icd10(code, icd10s) do
    desc = Map.fetch!(icd10s, code)
    ~E"<abbr title=\"<%= desc %>\"><%= code %></abbr>"
  end
end
