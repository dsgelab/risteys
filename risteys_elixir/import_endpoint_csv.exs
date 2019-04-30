# Import endpoint (aka Phenocode) information.
#
# NOTE! Before using this script, the endpoint Excel file has to be exported to CSV.
#
# Usage:
# mix run import_endpoint_csv.exs <path-to-file>
#
# where <path-to-file> points to the Endpoint file (provided by Aki) in CSV format.
#
# After that, this script can be used. It will:
# 1. Parse the list of ICD-9s and ICD-10s from defined files
# 2. Parse the Endpoint CSV file
# 3. Put the data from a CSV line to an Ecto schema
#    At this stage, some ICD-10 and ICD-9 are matched against the respective lists
# 4. Insert data in database

alias Risteys.{Repo, Phenocode, ICD10, ICD9}

Logger.configure(level: :info)
[filepath | _] = System.argv()

defmodule RegexICD do
  import Ecto.Query

  @icd10s Repo.all(from icd in ICD10, select: icd.code) |> MapSet.new()
  @icd9s Repo.all(from icd in ICD9, select: icd.code) |> MapSet.new()

  defp expand(regex, icd_version) do
    case regex do
      "" ->
        []

      "ANY" ->
        ["ANY"]

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
        |> Enum.filter(fn code -> Regex.match?(reg, code) end)
    end
  end

  def expand_icd10(regex), do: expand(regex, 10)
  def expand_icd9(regex), do: expand(regex, 9)
end

filepath
|> File.stream!()
|> CSV.decode!(headers: true)
|> Stream.map(fn %{
                   "TAGS" => tags,
                   "LEVEL" => level,
                   "OMIT" => omit,
                   "NAME" => code,
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
                   "version" => version,
                   "source" => source,
                   "PHEWEB" => pheweb
                 } ->
  omit =
    case omit do
      "" -> nil
      "1" -> true
    end

  level =
    case level do
      "" -> nil
      _ -> level
    end

  sex =
    case sex do
      "" -> nil
      _ -> String.to_integer(sex)
    end

  hd_mainonly =
    case hd_mainonly do
      "" -> nil
      "YES" -> true
    end

  # Parse some ICD-10 columns
  icd_10_regex = hd_icd_10
  hd_icd_10 = RegexICD.expand_icd10(hd_icd_10)

  cod_icd_10 =
    case cod_icd_10 do
      ^icd_10_regex -> hd_icd_10
      _ -> RegexICD.expand_icd10(cod_icd_10)
    end

  kela_reimb_icd = RegexICD.expand_icd10(kela_reimb_icd)

  # Parse some ICD-9 columns
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
      "" -> nil
      "YES" -> true
    end

  # Cancer
  canc_behav =
    case canc_behav do
      "" -> nil
      _ -> String.to_integer(canc_behav)
    end

  # Pheweb
  pheweb =
    case pheweb do
      "" -> nil
      "1" -> true
    end

  %Phenocode{
    code: code,
    longname: longname,
    tags: tags,
    level: level,
    omit: omit,
    sex: sex,
    include: include,
    pre_conditions: pre_conditions,
    conditions: conditions,
    outpat_icd: outpat_icd,
    hd_mainonly: hd_mainonly,
    hd_icd_10: hd_icd_10,
    hd_icd_9: hd_icd_9,
    hd_icd_8: hd_icd_8,
    hd_icd_10_excl: hd_icd_10_excl,
    hd_icd_9_excl: hd_icd_9_excl,
    hd_icd_8_excl: hd_icd_8_excl,
    cod_mainonly: cod_mainonly,
    cod_icd_10: cod_icd_10,
    cod_icd_9: cod_icd_9,
    cod_icd_8: cod_icd_8,
    cod_icd_10_excl: cod_icd_10_excl,
    cod_icd_9_excl: cod_icd_9_excl,
    cod_icd_8_excl: cod_icd_8_excl,
    oper_nom: oper_nom,
    oper_hl: oper_hl,
    oper_hp1: oper_hp1,
    oper_hp2: oper_hp2,
    kela_reimb: kela_reimb,
    kela_reimb_icd: kela_reimb_icd,
    kela_atc_needother: kela_atc_needother,
    kela_atc: kela_atc,
    canc_topo: canc_topo,
    canc_morph: canc_morph,
    canc_behav: canc_behav,
    special: special,
    version: version,
    source: source,
    pheweb: pheweb
  }
end)
|> Enum.each(&Repo.insert!(&1))
