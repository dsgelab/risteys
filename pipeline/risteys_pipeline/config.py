from pathlib import Path

# Input data

ROOT_DIR = Path("/data") / "processed_data"

FINREGISTRY_MINIMAL_PHENOTYPE_DATA_PATH = (
    ROOT_DIR / "minimal_phenotype" / "minimal_phenotype_file.csv"
)

FINREGISTRY_WIDE_FIRST_EVENTS_DATA_PATH = (
    ROOT_DIR / "endpointer" / "wide_first_events_endpoints_2021-12-20_no_OMITS.txt"
)

FINREGISTRY_ENDPOINTS_DATA_PATH = (
    ROOT_DIR / "endpointer" / "main" / "FINNGEN_ENDPOINTS_DF8_Final_2021-06-21.xlsx"
)

# Constants

FOLLOWUP_START = 1998.0
FOLLOWUP_END = 2020.99
