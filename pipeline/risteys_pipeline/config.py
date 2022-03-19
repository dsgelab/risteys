from pathlib import Path

# Input data

ROOT_DIR = Path("/data") / "processed_data"

FINREGISTRY_MINIMAL_PHENOTYPE_DATA_PATH = (
    ROOT_DIR / "minimal_phenotype" / "minimal_phenotype_2022-02-17.feather"
)

FINREGISTRY_DENSIFIED_FIRST_EVENTS_DATA_PATH = (
    ROOT_DIR / "endpointer" / "densified_first_events_DF8_no_omits_2022-03-17.feather"
)

FINREGISTRY_ENDPOINTS_DATA_PATH = (
    ROOT_DIR / "endpoint_metadata" / "finngen_endpoints_2021-09-02.csv"
)

# Constants

FOLLOWUP_START = 1998.0
FOLLOWUP_END = 2020.99
MIN_SUBJECTS_PERSONAL_DATA = 5