# Import endpoint (aka Phenocode) information.
#
# The endpoint Excel file has to be first exported to CSV.
#
# Then the regexes in it are expanded.
# At this time it is done using the sre_yield python library.
# Another, more meaningful, approach would be to get a list of matches by using
# each regex against the full list of ICD codes.
#
# After that, this script can be used. It will:
# 1. Parse the CSV file
# 2. Put the data from a CSV line to an Ecto schema
# 3. Insert data in database

alias Risteys.{Repo, Phenocode}

Repo.transaction(fn ->
  "assets/data/aki_endpoints__expanded2.csv"
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

    hd_icd_10 = String.split(hd_icd_10)
    hd_icd_9 = String.split(hd_icd_9)
    hd_icd_8 = String.split(hd_icd_8)
    hd_icd_10_excl = String.split(hd_icd_10_excl)
    hd_icd_9_excl = String.split(hd_icd_9_excl)
    hd_icd_8_excl = String.split(hd_icd_8_excl)

    cod_mainonly =
      case cod_mainonly do
        "" -> nil
        "YES" -> true
      end

    cod_icd_10 = String.split(cod_icd_10)
    cod_icd_9 = String.split(cod_icd_9)
    cod_icd_8 = String.split(cod_icd_8)
    cod_icd_10_excl = String.split(cod_icd_10_excl)
    cod_icd_9_excl = String.split(cod_icd_9_excl)
    cod_icd_8_excl = String.split(cod_icd_8_excl)

    oper_nom = String.split(oper_nom)
    oper_hl = String.split(oper_hl)
    oper_hp1 = String.split(oper_hp1)
    oper_hp2 = String.split(oper_hp2)

    kela_reimb =
      kela_reimb
      |> String.split()

    kela_reimb_icd = String.split(kela_reimb_icd)
    kela_atc = String.split(kela_atc)

    canc_behav =
      case canc_behav do
        "" -> nil
        _ -> String.to_integer(canc_behav)
      end

    canc_topo = String.split(canc_topo)

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
  # NOTE take only of subset for development purpose
  ### |> Stream.take(100)
  |> Enum.each(&Repo.insert!(&1))
end)
