# Import ICD10s in the database.
#
# Usage:
# mix run import_icd10.exs <path-to-data-dir>
#
# <path-to-data-dir> must contain 2 files:
# - the ICD-10-CM file named "icd10cm_codes_2019.tsv"
#   This file was taken from
#   ftp://ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/ICD10CM/2019/
# - the ICD-10 Finnish version, named "ICD10_finn_codedesc.tsv"
#   This file was derived from a file provided by Aki
#   ("ICD10_koodistopalvelu_2015-08_26.txt"), it has the following shape:
#        code	longname
#        A00-B99	Certain infectious and parasitic diseases
#        A00-A09	Intestinal infectious diseases
#        A00	Cholera

require Logger
alias Risteys.{Repo, Icd10}

Logger.configure(level: :info)
[data_dir | _] = System.argv()
icd10cm = Path.join(data_dir, "icd10cm_codes_2019.tsv")
icd10finn = Path.join(data_dir, "ICD10_finn_codedesc.tsv")

# US ICD-10s
Logger.info("Loading ICD-10-CM")

icd10s =
  icd10cm
  |> File.stream!()
  |> CSV.decode!(separator: ?\t)
  |> Enum.reduce(%{}, fn [code, description], acc ->
    Map.put(acc, code, description)
  end)

# Finnish ICD-10s
Logger.info("Loading Finnish ICD-10s")

icd10s =
  icd10finn
  |> File.stream!()
  |> CSV.decode!(separator: ?\t, headers: true)
  |> Enum.reduce(icd10s, fn %{"code" => code, "longname" => description}, acc ->
    code = code |> String.replace(".", "")
    Map.put_new(acc, code, description)
  end)

Logger.info("Inserting ICD-10s in the database.")

icd10s
|> Enum.map(fn {code, description} ->
  Repo.insert!(%Icd10{code: code, description: description})
end)
