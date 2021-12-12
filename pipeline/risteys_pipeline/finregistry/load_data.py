"""Functions for loading the FinRegistry datasets"""

import pandas as pd
from risteys_pipeline.config import *
from risteys_pipeline.log import logger
from risteys_pipeline.finregistry.preprocess_data import (
    preprocess_minimal_phenotype_data,
    preprocess_wide_first_events_data,
    preprocess_endpoints_data,
)


def load_minimal_phenotype_data(
    data_path=FINREGISTRY_MINIMAL_PHENOTYPE_DATA_PATH, preprocess=False
):
    """Loads minimal phenotype data as a dataframe and optionally performs preprocessing."""
    logger.info("Loading minimal phenotype data")
    cols = ["FINREGISTRYID", "date_of_birth", "death_date", "sex"]
    df = pd.read_csv(data_path, usecols=cols, header=0, sep=",")
    if preprocess:
        df = preprocess_minimal_phenotype_data(df)
    return df


def load_wide_first_events_data(
    exposure,
    outcome,
    data_path=FINREGISTRY_WIDE_FIRST_EVENTS_DATA_PATH,
    preprocess=False,
):
    """Loads wide first_events data for two endpoints as a dataframe and optionally performs preprocessing."""
    logger.info("Loading wide first events data")
    cols = [
        "FINREGISTRYID",
        exposure,
        exposure + "_AGE",
        exposure + "_YEAR",
        outcome,
        outcome + "_AGE",
        outcome + "_YEAR",
    ]
    df = pd.read_csv(data_path, header=0, sep="\t", usecols=cols)
    if preprocess:
        df = preprocess_wide_first_events_data(df)
    return df


def load_endpoints_data(data_path=FINREGISTRY_ENDPOINTS_DATA_PATH, preprocess=False):
    """Loads endpoints data as a dataframe and optionally performs preprocessing."""
    # TODO: replace excel with csv for speed
    logger.info("Loading endpoints data")
    cols = ["NAME", "SEX", "OMIT"]
    df = pd.read_excel(data_path, sheet_name="Sheet 1", usecols=cols, header=0)
    if preprocess:
        df = preprocess_endpoints_data(df)
    return df
