"""Functions for loading the FinRegistry datasets"""

import pandas as pd
from risteys_pipeline.config import *


def load_minimal_phenotype_data(data_path=FINREGISTRY_MINIMAL_PHENOTYPE_DATA_PATH):
    """Loads minimal phenotype data as a data frame."""
    cols = ["FINREGISTRYID", "date_of_birth", "sex"]
    df = pd.read_csv(data_path, usecols=cols, header=0, sep=",")
    return df


def load_first_events_data(data_path=FINREGISTRY_FIRST_EVENTS_DATA_PATH):
    """Loads minimal phenotype data as a data frame."""
    df = pd.read_csv(data_path, header=0, sep=",")
    return df


def load_endpoints_data(data_path=FINREGISTRY_ENDPOINTS_DATA_PATH):
    """Loads endpoints data as a data frame."""
    # TODO: replace excel with csv
    cols = ["NAME", "SEX"]
    df = pd.read_excel(data_path, sheet_name="Sheet 1", usecols=cols)
    return df

