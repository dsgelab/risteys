from pathlib import Path

# Input data

ROOT_DIR = Path("/data") / "processed_data"

FINREGISTRY_MINIMAL_PHENOTYPE_DATA_PATH = (
    ROOT_DIR / "minimal_phenotype" / "minimal_phenotype.feather"
)

FINREGISTRY_LONG_FIRST_EVENTS_DATA_PATH = (
    ROOT_DIR / "endpointer" / "long_first_events_2021-09-04.feather"
)

FINREGISTRY_ENDPOINTS_DATA_PATH = (
    ROOT_DIR / "endpointer" / "main" / "finngen_endpoints_2021-06-21.csv"
)

# Constants

FOLLOWUP_START = 1998.0
FOLLOWUP_END = 2020.99
