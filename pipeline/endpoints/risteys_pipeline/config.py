from pathlib import Path


# --- FinRegistry
# Input data
ROOT_DIR = Path("/data") / "processed_data"
FINREGISTRY_MINIMAL_PHENOTYPE_DATA_PATH = ROOT_DIR / "minimal_phenotype" / "minimal_phenotype_2022-03-28.feather"
FINREGISTRY_DENSIFIED_FIRST_EVENTS_DATA_PATH = ROOT_DIR / "endpointer" / "densified_first_events_DF10_no_omits_2022-09-20.feather"
FINREGISTRY_ENDPOINT_DEFINITIONS_DATA_PATH = ROOT_DIR / "endpoint_metadata" / "endpoints_DF10_2022-10-10.csv"

# Output directory
FINREGISTRY_OUTPUT_DIR = Path("/data") / "projects" / "risteys"


# --- FinnGen
# Input data
FINNGEN_DATA_DIR               = Path()
FINNGEN_ENDPOINT_DEFINITIONS   = FINNGEN_DATA_DIR / Path()
FINNGEN_MINIMAL_PHENOTYPE      = FINNGEN_DATA_DIR / Path()
FINNGEN_COVARIATES             = FINNGEN_DATA_DIR / Path()
FINNGEN_DENSIFIED_FIRST_EVENTS = FINNGEN_DATA_DIR / Path()
FINNGEN_DETAILED_LONGITUDINAL  = FINNGEN_DATA_DIR / Path()

# Output directory
FINNGEN_OUTPUT_DIRECTORY = Path()

# --- Common
# Constants

# Follow-up start and end year for survival analyses
FOLLOWUP_START = 1998.0
FOLLOWUP_END = 2023.32  # 2023-04-28 according to the data documentation

# Minimum number of subjects
MIN_SUBJECTS_PERSONAL_DATA = 5
MIN_SUBJECTS_SURVIVAL_ANALYSIS = 50
