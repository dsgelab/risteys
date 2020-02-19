# Import endpoint (aka Phenocode) information.
#
# NOTE! Before using this script, the endpoint Excel file has to be converted to CSV.
#
#
# Usage
# -----
# mix run import_endpoint_csv.exs <path-to-endpoints-file> <path-to-tagged-ordered-endpoints-file> <path-to-categories-file>
#
# <path-to-endpoints-file>
#   Endpoint file in CSV format.
#   Provided in the FinnGen data.
#   This file usually have the name "finngen_RX_endpoint_definitions.txt" and is
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
#
# Notes
# -----
# This is a 3-step process.
#
# First step is to parse the endpoint main tag.
#
# Second step is to parse the endpoint categories.
#
# Third step is to parse endpoint definition file and import endpoints into the database:
# 1. Get the list of ICD-9s and ICD-10s from the database.
#    So these should be imported before running this script, see:
#    - import_icd10.exs
#    - import_icd9.exs
# 2. Parse the Endpoint CSV file
# 3. Put the phenocode data from a CSV line into Ecto schemas.
#    At this stage, some ICD-10 and ICD-9 are matched against thir tables in the database.
#    Phenocode <-> ICD-{10,9} are built.
# 4. Insert data in database.

require Logger
alias Risteys.{Repo, Phenocode, Icd10, Icd9, PhenocodeIcd10, PhenocodeIcd9}

Logger.configure(level: :info)
[endpoints_path, tagged_path, categories_path | _] = System.argv()

defmodule RegexICD do
  import Ecto.Query

  @icd10s Repo.all(from icd in Icd10, select: %{code: icd.code, id: icd.id}) |> MapSet.new()
  @icd9s Repo.all(from icd in Icd9, select: %{code: icd.code, id: icd.id}) |> MapSet.new()

  defp expand(regex, icd_version) do
    Logger.debug(fn -> "expanding regex: #{regex}" end)

    case regex do
      "" ->
        []

      "NA" ->
        []

      # not a valid ICD
      "ANY" ->
        []

      _ ->
        # Match only against upper most ICD in the tree.
        # For example make E[7-9] match E7 but not E700.
        regex = "^(#{regex})$"
        reg = Regex.compile!(regex)

        icds =
          case icd_version do
            10 -> @icd10s
            9 -> @icd9s
          end

        icds
        |> Enum.filter(fn %{code: code} -> Regex.match?(reg, code) end)
    end
  end

  def expand_icd10(regex), do: expand(regex, 10)
  def expand_icd9(regex), do: expand(regex, 9)
end

defmodule AssocICDs do
  def insert(registry, icd_version, phenocode_id, icds) do
    case icd_version do
      10 ->
        Enum.each(icds, fn icd ->
          Logger.debug("ICD-10: #{inspect(icd)}")

          PhenocodeIcd10.changeset(
            %PhenocodeIcd10{},
            %{
              registry: registry,
              phenocode_id: phenocode_id,
              icd10_id: icd.id
            }
          )
          |> Repo.insert!()
        end)

      9 ->
        Enum.each(icds, fn icd ->
          Logger.debug("ICD-9: #{inspect(icd)}")

          PhenocodeIcd9.changeset(
            %PhenocodeIcd9{},
            %{
              registry: registry,
              phenocode_id: phenocode_id,
              icd9_id: icd.id
            }
          )
          |> Repo.insert!()
        end)
    end
  end
end

###
# PARSE MAIN TAG
###
main_tags =
  tagged_path
  |> File.stream!()
  |> CSV.decode!(headers: true)
  |> Enum.reduce(%{}, fn %{"TAG" => tag, "NAME" => name}, acc ->
    Map.put(acc, name, tag)
  end)

###
# PARSE CATEGORIES
###
categories =
  categories_path
  |> File.stream!()
  |> CSV.decode!(headers: true)
  |> Enum.reduce(
    %{},
    fn %{"code" => code, "CHAPTER" => chapter, "OTHER" => other}, acc ->
      category =
        cond do
          chapter != "" ->
            chapter

          other != "" ->
            other
        end

      Map.put(acc, code, category)
    end
  )

###
# IMPORT ENDPOINTS
###
endpoints_path
|> File.stream!()
|> CSV.decode!(headers: true)
# Omit first line of data: it is a comment line
|> Enum.drop(1)
|> Enum.each(fn %{
                  "TAGS" => tags,
                  "LEVEL" => level,
                  "OMIT" => omit,
                  "NAME" => name,
                  "LONGNAME" => longname,
                  "SEX" => sex,
                  "INCLUDE" => include,
                  "PRE_CONDITIONS" => pre_conditions,
                  "CONDITIONS" => conditions,
                  "OUTPAT_ICD" => outpat_icd,
                  "HD_MAINONLY" => hd_mainonly,
                  "HD_ICD_10" => hd_icd_10,
                  "HD_ICD_9" => hd_icd_9,
                  "HD_ICD_8" => hd_icd_8,
                  "HD_ICD_10_EXCL" => hd_icd_10_excl,
                  "HD_ICD_9_EXCL" => hd_icd_9_excl,
                  "HD_ICD_8_EXCL" => hd_icd_8_excl,
                  "COD_MAINONLY" => cod_mainonly,
                  "COD_ICD_10" => cod_icd_10,
                  "COD_ICD_9" => cod_icd_9,
                  "COD_ICD_8" => cod_icd_8,
                  "COD_ICD_10_EXCL" => cod_icd_10_excl,
                  "COD_ICD_9_EXCL" => cod_icd_9_excl,
                  "COD_ICD_8_EXCL" => cod_icd_8_excl,
                  "OPER_NOM" => oper_nom,
                  "OPER_HL" => oper_hl,
                  "OPER_HP1" => oper_hp1,
                  "OPER_HP2" => oper_hp2,
                  "KELA_REIMB" => kela_reimb,
                  "KELA_REIMB_ICD" => kela_reimb_icd,
                  "KELA_ATC_NEEDOTHER" => kela_atc_needother,
                  "KELA_ATC" => kela_atc,
                  "CANC_TOPO" => canc_topo,
                  "CANC_MORPH" => canc_morph,
                  "CANC_BEHAV" => canc_behav,
                  "Special" => special,
                  "version" => version
                } ->
  Logger.info("Processing phenocode: #{name}")

  omit =
    case omit do
      "NA" -> false
      "1" -> true
      "2" -> true
    end

  level =
    case level do
      "NA" -> nil
      _ -> level
    end

  sex =
    case sex do
      "NA" -> nil
      _ -> String.to_integer(sex)
    end

  # Set category
  main_tag = Map.get(main_tags, name)
  category = Map.get(categories, main_tag, "Unknown")

  hd_mainonly =
    case hd_mainonly do
      "NA" -> nil
      "YES" -> true
    end

  # Parse some ICD-10 columns
  Logger.debug("Parsing ICD-10s for #{name}")
  icd_10_regex = hd_icd_10
  hd_icd_10 = RegexICD.expand_icd10(hd_icd_10)

  cod_icd_10 =
    case cod_icd_10 do
      ^icd_10_regex -> hd_icd_10
      _ -> RegexICD.expand_icd10(cod_icd_10)
    end

  kela_reimb_icd = RegexICD.expand_icd10(kela_reimb_icd)

  # Parse some ICD-9 columns
  Logger.debug("Parsing ICD-9s #{name}")
  icd_9_regex = hd_icd_9
  hd_icd_9 = RegexICD.expand_icd9(icd_9_regex)

  cod_icd_9 =
    case hd_icd_9 do
      ^icd_9_regex -> hd_icd_9
      _ -> RegexICD.expand_icd9(cod_icd_9)
    end

  # Remove $!$ from ICD-8
  hd_icd_8 = hd_icd_8 |> String.replace("$!$", "")
  hd_icd_8_excl = hd_icd_8_excl |> String.replace("$!$", "")
  cod_icd_8 = cod_icd_8 |> String.replace("$!$", "")
  cod_icd_8_excl = cod_icd_8_excl |> String.replace("$!$", "")

  # Cause of death
  cod_mainonly =
    case cod_mainonly do
      "NA" -> nil
      "YES" -> true
    end

  # Cancer
  canc_behav =
    case canc_behav do
      "NA" -> nil
      _ -> String.to_integer(canc_behav)
    end

  Logger.debug("Inserting phenocode #{name} in DB")

  phenocode =
    Phenocode.changeset(%Phenocode{}, %{
      name: name,
      longname: longname,
      tags: tags,
      category: category,
      level: level,
      omit: omit,
      sex: sex,
      include: include,
      pre_conditions: pre_conditions,
      conditions: conditions,
      outpat_icd: outpat_icd,
      hd_mainonly: hd_mainonly,
      hd_icd_8: hd_icd_8,
      hd_icd_10_excl: hd_icd_10_excl,
      hd_icd_9_excl: hd_icd_9_excl,
      hd_icd_8_excl: hd_icd_8_excl,
      cod_mainonly: cod_mainonly,
      cod_icd_8: cod_icd_8,
      cod_icd_10_excl: cod_icd_10_excl,
      cod_icd_9_excl: cod_icd_9_excl,
      cod_icd_8_excl: cod_icd_8_excl,
      oper_nom: oper_nom,
      oper_hl: oper_hl,
      oper_hp1: oper_hp1,
      oper_hp2: oper_hp2,
      kela_reimb: kela_reimb,
      kela_atc_needother: kela_atc_needother,
      kela_atc: kela_atc,
      canc_topo: canc_topo,
      canc_morph: canc_morph,
      canc_behav: canc_behav,
      special: special,
      version: version
    })

  case Repo.insert(phenocode) do
    {:ok, struct} ->
      Logger.debug("Successfully inserted #{name}.")
      # Build Phenocode<->ICD-{10,9} associations
      Logger.debug("Inserting ICD associations for #{name}")
      AssocICDs.insert("HD", 10, struct.id, hd_icd_10)
      AssocICDs.insert("COD", 10, struct.id, cod_icd_10)
      AssocICDs.insert("KELA_REIMB", 10, struct.id, kela_reimb_icd)

      AssocICDs.insert("HD", 9, struct.id, hd_icd_9)
      AssocICDs.insert("COD", 9, struct.id, cod_icd_9)

    {:error, changeset} ->
      Logger.warn("Could not insert #{name}: #{inspect(changeset)}")
  end
end)
