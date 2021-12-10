import os

# Input data
ROOT_DIR = os.path.join("data", "processed_data")

FINREGISTRY_MINIMAL_PHENOTYPE_DATA_PATH = os.path.join(
    ROOT_DIR, "notebooks", "mpf", "minimal_phenotype_file.csv"
)
FINREGISTRY_FIRST_EVENTS_DATA_PATH = os.path.join(
    ROOT_DIR,
    "endpointer",
    "main",
    "finngen_endpoints_04-09-2021_v2.densified_OMITS.txt",
)
FINREGISTRY_ENDPOINTS_DATA_PATH = os.path.join(
    ROOT_DIR, "endpointer", "main", "FINNGEN_ENDPOINTS_DF8_Final_2021-06-21.xlsx"
)

# Constants
FOLLOWUP_START = 1998.0
FOLLOWUP_END = 2020.99
