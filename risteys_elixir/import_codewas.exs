require Logger

Logger.configure(level: :info)

[codewas_file, codes_info_path | _] = System.argv()

# Deleting existing CodeWAS data to make a clean import
Logger.info("Deleting existing CodeWAS data to make a clean import")
Risteys.Repo.delete_all(Risteys.CodeWAS.Cohort)
Risteys.Repo.delete_all(Risteys.CodeWAS.Codes)

# Load codes_info
Logger.info("Loading codes info")
codes_info = Risteys.CodeWAS.build_codes_info(codes_info_path)

# Import CodeWAS data
Logger.info("Importing all CodeWAS data")
Risteys.CodeWAS.import_file(codewas_file, codes_info)

Logger.info("Done.")
