require Logger

Logger.configure(level: :info)

[input_dir, codes_info_path | _] = System.argv()

# Deleting existing CodeWAS data to make a clean import
Logger.info("Deleting existing CodeWAS data to make a clean import")
Risteys.Repo.delete_all(Risteys.CodeWAS.Cohort)
Risteys.Repo.delete_all(Risteys.CodeWAS.Codes)

# Import cohort data from all CodeWAS JSON files
Logger.info("Importing all CodeWAS JSON files")
input_dir
|> Path.expand()
|> Path.join("*.json")
|> Path.wildcard()
|> Enum.each(&Risteys.CodeWAS.import_cohort_file(&1))

# Load codes_info
Logger.info("Loading codes info")
codes_info = Risteys.CodeWAS.build_codes_info(codes_info_path)

# Import codes data from all CodeWAS CSV files
Logger.info("Importing all CodeWAS CSV files")

input_dir
|> Path.expand()
|> Path.join("*.csv")
|> Path.wildcard()
|> Enum.each(&Risteys.CodeWAS.import_codes_file(&1, codes_info))

Logger.info("Done.")
