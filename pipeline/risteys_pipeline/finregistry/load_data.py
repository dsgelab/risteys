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
    """Loads minimal phenotype data as a dataframe and optionally performs preprocessing.
    
    Args:
        data_path (str, optional): file path of the minimal phenotype csv file
        preprocessing (bool, optional): will the data be preprocessed 

    Returns: 
        df (DataFrame): minimal phenotype dataframe
    """
    cols = ["FINREGISTRYID", "date_of_birth", "death_date", "sex"]
    dtypes = {
        "FINREGISTRYID": "str",
        "date_of_birth": "str",
        "death_date": "str",
        "sex": "float",  # NAs are not allowed for int in pandas
    }
    date_cols = ["date_of_birth", "death_date"]
    df = pd.read_csv(
        data_path, usecols=cols, dtype=dtypes, parse_dates=date_cols, header=0, sep=","
    )
    logger.info(f"{df.shape[0]} rows loaded")
    if preprocess:
        df = preprocess_minimal_phenotype_data(df)
    return df


def load_wide_first_events_data(
    exposure,
    outcome,
    nrows=None,
    data_path=FINREGISTRY_WIDE_FIRST_EVENTS_DATA_PATH,
    preprocess=False,
):
    """Loads wide first_events data for two endpoints as a dataframe and optionally performs preprocessing.
    
    Args:
        exposure (str): name of the exposure endpoint
        outcome (str): name of the outcome endpoint
        nrows (int, optional): number of rows to read
        data_path (str, optional): file path of the first events csv file
        preprocess (bool, optional): will the data be preprocessed

    Returns:
        df (DataFrame): first events dataframe with exposure and outcome related columns
    """
    cols = [
        "FINREGISTRYID",
        exposure + "_NEVT",
        exposure + "_AGE",
        outcome + "_NEVT",
        outcome + "_AGE",
    ]
    df = pd.read_csv(data_path, header=0, sep=",", usecols=cols, nrows=nrows)[cols]
    logger.info(f"{df.shape[0]} rows loaded")
    if preprocess:
        df = preprocess_wide_first_events_data(df)
    return df


def load_endpoints_data(data_path=FINREGISTRY_ENDPOINTS_DATA_PATH, preprocess=False):
    """Loads endpoints data as a dataframe and optionally performs preprocessing.
    
    Args:
        data_path (str, optional): file path of the first events csv file
        preprocess (bool, optional): will the data be preprocessed

    Returns:
        df (DataFrame): endpoints dataframe
    """
    # TODO: replace excel with csv for speed
    cols = ["NAME", "SEX", "OMIT"]
    df = pd.read_excel(data_path, sheet_name="Sheet 1", usecols=cols, header=0)
    logger.info(f"{df.shape[0]} rows loaded")
    if preprocess:
        df = preprocess_endpoints_data(df)
    return df
