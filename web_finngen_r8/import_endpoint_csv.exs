# Import endpoint (aka Phenocode) information.
#
# Usage
# -----
# mix run import_endpoint_csv.exs \
#     <path-to-endpoints-file> \
#     <path-to-tagged-ordered-endpoints-file> \
#     <path-to-categories-file> \
#     <path-to-icd10fi>
#
# <path-to-endpoints-file>
#   Endpoint file in CSV format.
#   Provided in the FinnGen data.
#   This file usually have the name "finngen_RX_endpoint_definitions.txt"
#
# <path-to-tagged-ordered-endpoints-file>
#   CSV file with header: TAG,CLASS,NAME
#   Provided by Aki.
#   It is used to get the main tag for each endpoint.
#
# <path-to-taglist-file>
#   CSV file with header: code,CHAPTER,OTHER
#   Provided by Aki.
#   It is used to map endpoints to categories.
#
# <path-to-icd10fi>
#   List of Finnish ICD-10, in CSV format and UTF-8.
#   Provided by Aki.
#   It is used to match an ICD-10 definition into a list of ICD-10s.
#   Must contain columns: CodeId, ParentId
#

alias Risteys.{Repo, Phenocode, PhenocodeIcd10, Icd10}
require Logger
import Ecto.Query

Logger.configure(level: :info)

# INPUT
Logger.info("Loading ICD-10 from files")

[
  endpoints_path,
  tagged_path,
  categories_path,
  icd10fi_file_path
] = System.argv()

# HELPERS
defmodule AssocICDs do
  def insert_or_update(registry, 10, phenocode, icds) do
    # Delete all previous associations of (Phenocode, Registry) -> ICD-10
    Repo.delete_all(
      from link in PhenocodeIcd10,
        where: link.phenocode_id == ^phenocode.id and link.registry == ^registry
    )

    # Add new associations
    Enum.each(icds, fn icd ->
      Logger.debug("Inserting: #{registry}, ICD-10, #{inspect(icd)}")
      icd_db = Repo.get_by!(Icd10, code: icd)

      case Repo.get_by(
             PhenocodeIcd10,
             registry: registry,
             phenocode_id: phenocode.id,
             icd10_id: icd_db.id
           ) do
        nil -> %PhenocodeIcd10{}
        existing -> existing
      end
      |> PhenocodeIcd10.changeset(%{
        registry: registry,
        phenocode_id: phenocode.id,
        icd10_id: icd_db.id
      })
      |> Repo.insert_or_update!()
    end)
  end
end

# 1. Get meta information for endpoint processing
####
Logger.info("Pre-processing endpoint metadata files")
tags =
  tagged_path
  |> File.stream!()
  |> CSV.decode!(headers: true)
  |> Enum.reduce(%{}, fn %{"TAG" => tag, "NAME" => name}, acc ->
    Map.put(acc, name, tag)
  end)

categories =
  categories_path
  |> File.stream!()
  |> CSV.decode!(headers: true)
  |> Enum.reduce(%{}, fn %{"code" => tag, "CHAPTER" => chapter, "OTHER" => other}, acc ->
    category =
      if chapter != "" do
        chapter
      else
        other
      end

    Map.put(acc, tag, category)
  end)

{
  icd10s,
  map_undotted_dotted,
  map_child_parent,
  map_parent_children
} = Risteys.Icd10.init_parser(icd10fi_file_path)


# 2. Clean-up & Transform endpoints
####
Logger.info("Cleaning-up endpoint from the definition files")
endpoints_path
|> File.stream!()
|> CSV.decode!(headers: true)

# Omit comment line
|> Stream.reject(fn %{"NAME" => name} -> String.starts_with?(name, "#") end)

# Replace NA values with nil
|> Stream.map(fn row ->
  Enum.reduce(row, %{}, fn {header, value}, acc ->
    value = if value == "NA", do: nil, else: value
    Map.put_new(acc, header, value)
  end)
end)

# Add endpoint category
|> Stream.map(fn row ->
  %{"NAME" => name} = row

  case Map.fetch(tags, name) do
    :error ->
      Map.put_new(row, :category, "Unknown")

    {:ok, tag} ->
      %{^tag => cat} = categories
      Map.put_new(row, :category, cat)
  end
end)

# Parse ICD-10: HD
|> Stream.map(fn row ->
  %{"HD_ICD_10" => hd} = row
  expanded = Risteys.Icd10.parse_rule(hd, icd10s, map_child_parent, map_parent_children)
  Map.put_new(row, :hd_icd10s_exp, expanded)
end)

# Parse excl ICD-10: HD
|> Stream.map(fn row ->
  %{"HD_ICD_10_EXCL" => hd_excl} = row
  expanded = Risteys.Icd10.parse_rule(hd_excl, icd10s, map_child_parent, map_parent_children)
  Map.put_new(row, :hd_icd10s_excl_exp, expanded)
end)

# Parse ICD-10: OUTPAT
|> Stream.map(fn row ->
  %{
    "OUTPAT_ICD" => outpat,
    "HD_ICD_10" => hd
  } = row

  expanded =
    case outpat do
      ^hd -> row.hd_icd10s_exp
      _ -> Risteys.Icd10.parse_rule(outpat, icd10s, map_child_parent, map_parent_children)
    end

  Map.put_new(row, :outpat_icd10s_exp, expanded)
end)

# Parse ICD-10: COD
|> Stream.map(fn row ->
  %{
    "COD_ICD_10" => cod,
    "HD_ICD_10" => hd
  } = row

  expanded =
    case cod do
      ^hd -> row.hd_icd10s_exp
      _ -> Risteys.Icd10.parse_rule(cod, icd10s, map_child_parent, map_parent_children)
    end

  Map.put_new(row, :cod_icd10s_exp, expanded)
end)

# Parse excl ICD-10: COD
|> Stream.map(fn row ->
  %{"COD_ICD_10_EXCL" => cod_excl} = row
  expanded = Risteys.Icd10.parse_rule(cod_excl, icd10s, map_child_parent, map_parent_children)
  Map.put_new(row, :cod_icd10s_excl_exp, expanded)
end)

# Parse ICD-10: KELA
|> Stream.map(fn row ->
  %{
    "KELA_REIMB_ICD" => kela,
    "HD_ICD_10" => hd
  } = row

  expanded =
    case kela do
      ^hd -> row.hd_icd10s_exp
      _ -> Risteys.Icd10.parse_rule(kela, icd10s, map_child_parent, map_parent_children)
    end

  Map.put_new(row, :kela_icd10s_exp, expanded)
end)

# Convert ICD-10s to dotted notation
|> Stream.map(fn row ->
  dotted = %{
    outpat_icd10s_exp:
      Enum.map(row.outpat_icd10s_exp, &Risteys.Icd10.to_dotted(&1, map_undotted_dotted)),
    hd_icd10s_exp: Enum.map(row.hd_icd10s_exp, &Risteys.Icd10.to_dotted(&1, map_undotted_dotted)),
    hd_icd10s_excl_exp:
      Enum.map(row.hd_icd10s_excl_exp, &Risteys.Icd10.to_dotted(&1, map_undotted_dotted)),
    cod_icd10s_exp:
      Enum.map(row.cod_icd10s_exp, &Risteys.Icd10.to_dotted(&1, map_undotted_dotted)),
    cod_icd10s_excl_exp:
      Enum.map(row.cod_icd10s_excl_exp, &Risteys.Icd10.to_dotted(&1, map_undotted_dotted)),
    kela_icd10s_exp:
      Enum.map(row.kela_icd10s_exp, &Risteys.Icd10.to_dotted(&1, map_undotted_dotted))
  }

  Map.merge(row, dotted)
end)
|> Stream.each(fn row ->
  %{
    "NAME" => name,
    "CONDITIONS" => conditions
  } = row

  if not is_nil(conditions) and String.contains?(conditions, ["(", ")"]) do
    Logger.warn(
      "Endpoint #{name} has 'conditions' with '(' or ')': it will be incorrectly displayed."
    )
  end
end)

# 3. Add endpoints to DB
####
|> Enum.each(fn row ->
  Logger.info("Inserting/updating: #{row["NAME"]}")

  phenocode =
    case Repo.get_by(Phenocode, name: row["NAME"]) do
      nil -> %Phenocode{}
      existing -> existing
    end
    |> Phenocode.changeset(%{
      name: row["NAME"],
      tags: row["TAGS"],
      level: row["LEVEL"],
      omit: row["OMIT"],
      longname: row["LONGNAME"],
      sex: row["SEX"],
      include: row["INCLUDE"],
      pre_conditions: row["PRE_CONDITIONS"],
      conditions: row["CONDITIONS"],
      outpat_icd: row["OUTPAT_ICD"],
      hd_mainonly: row["HD_MAINONLY"],
      hd_icd_10_atc: row["HD_ICD_10_ATC"],
      hd_icd_10: row["HD_ICD_10"],
      hd_icd_9: row["HD_ICD_9"],
      hd_icd_8: row["HD_ICD_8"],
      hd_icd_10_excl: row["HD_ICD_10_EXCL"],
      hd_icd_9_excl: row["HD_ICD_9_EXCL"],
      hd_icd_8_excl: row["HD_ICD_8_EXCL"],
      cod_mainonly: row["COD_MAINONLY"],
      cod_icd_10: row["COD_ICD_10"],
      cod_icd_9: row["COD_ICD_9"],
      cod_icd_8: row["COD_ICD_8"],
      cod_icd_10_excl: row["COD_ICD_10_EXCL"],
      cod_icd_9_excl: row["COD_ICD_9_EXCL"],
      cod_icd_8_excl: row["COD_ICD_8_EXCL"],
      oper_nom: row["OPER_NOM"],
      oper_hl: row["OPER_HL"],
      oper_hp1: row["OPER_HP1"],
      oper_hp2: row["OPER_HP2"],
      kela_reimb: row["KELA_REIMB"],
      kela_reimb_icd: row["KELA_REIMB_ICD"],
      kela_atc_needother: row["KELA_ATC_NEEDOTHER"],
      kela_atc: row["KELA_ATC"],
      kela_vnro_needother: row["KELA_VNRO_NEEDOTHER"],
      kela_vnro: row["KELA_VNRO"],
      canc_topo: row["CANC_TOPO"],
      canc_topo_excl: row["CANC_TOPO_EXCL"],
      canc_morph: row["CANC_MORPH"],
      canc_morph_excl: row["CANC_MORPH_EXCL"],
      canc_behav: row["CANC_BEHAV"],
      special: row["Special"],
      version: row["version"],
      parent: row["PARENT"],
      latin: row["Latin"],
      category: row.category
    })
    |> Repo.insert_or_update!()

  AssocICDs.insert_or_update("OUTPAT", 10, phenocode, row.outpat_icd10s_exp)
  AssocICDs.insert_or_update("HD", 10, phenocode, row.hd_icd10s_exp)
  AssocICDs.insert_or_update("HD_EXCL", 10, phenocode, row.hd_icd10s_excl_exp)
  AssocICDs.insert_or_update("COD", 10, phenocode, row.cod_icd10s_exp)
  AssocICDs.insert_or_update("COD_EXCL", 10, phenocode, row.cod_icd10s_excl_exp)
  AssocICDs.insert_or_update("KELA", 10, phenocode, row.kela_icd10s_exp)
end)
