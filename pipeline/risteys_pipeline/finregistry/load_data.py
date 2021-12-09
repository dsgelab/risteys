"""Functions for loading the FinRegistry datasets"""

import pandas as pd
from risteys_pipeline.config import *
from risteys_pipeline.log import logger


def load_minimal_phenotype_data(data_path=FINREGISTRY_MINIMAL_PHENOTYPE_DATA_PATH):
    """Loads minimal phenotype data as a data frame."""
    logger.info("Loading minimal phenotype data")
    cols = ["FINREGISTRYID", "date_of_birth", "sex"]
    df = pd.read_csv(data_path, usecols=cols, header=0, sep=",")
    return df


def load_first_events_data(data_path=FINREGISTRY_FIRST_EVENTS_DATA_PATH):
    """Loads minimal phenotype data as a data frame."""
    logger.info("Loading first events data")
    cols = ["FINNGENID", "ENDPOINT", "AGE", "YEAR", "NEVT"]
    df = pd.read_csv(data_path, header=0, sep=",", usecols=cols)
    return df


def load_endpoints_data(data_path=FINREGISTRY_ENDPOINTS_DATA_PATH):
    """Loads endpoints data as a data frame."""
    # TODO: replace excel with csv for speed
    logger.info("Loading endpoints data")
    cols = ["NAME", "SEX", "OMIT"]
    df = pd.read_excel(data_path, sheet_name="Sheet 1", usecols=cols, header=0)
    return df
