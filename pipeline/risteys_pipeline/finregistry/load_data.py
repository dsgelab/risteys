"""Functions for loading the FinRegistry datasets"""

import pandas as pd
import numpy as np
from risteys_pipeline.config import (
    FINREGISTRY_MINIMAL_PHENOTYPE_DATA_PATH,
    FINREGISTRY_ENDPOINT_DEFINITIONS_DATA_PATH,
    FINREGISTRY_DENSIFIED_FIRST_EVENTS_DATA_PATH,
)
from risteys_pipeline.utils.log import logger
from risteys_pipeline.utils.utils import to_decimal_year

SEX_FEMALE_ENDPOINTS = 2.0
SEX_MALE_ENDPOINTS = 1.0
SEX_FEMALE_MINIMAL_PHENOTYPE = 1.0
SEX_MALE_MINIMAL_PHENOTYPE = 0.0


def load_data():
    """
    Loads the following datasets using the data paths on config:
    - endpoint definitions
    - minimal phenotype 
    - first events 

    Args:
        None

    Returns
        (endpoint_definitions, minimal_phenotype, first_events) (tuple)
    """
    endpoint_definitions = load_endpoint_definitions_data()
    minimal_phenotype = load_minimal_phenotype_data()
    first_events = load_first_events_data(endpoint_definitions, minimal_phenotype)
    return (endpoint_definitions, minimal_phenotype, first_events)


def load_minimal_phenotype_data(data_path=FINREGISTRY_MINIMAL_PHENOTYPE_DATA_PATH):
    """
    Loads and applies the following steps to minimal phenotype data:
    - drop rows with no FinRegistry ID
    - drop duplicated rows
    - add birth and death year
    - drop redundant columns (date_of_birth, death_date)
    - set `index_person` to boolean
    - add `female` and drop `sex`
    
    Args:
        data_path (str, optional): file path of the minimal phenotype csv file

    Returns: 
        df (DataFrame): minimal phenotype dataframe
    """
    cols = ["FINREGISTRYID", "date_of_birth", "death_date", "sex", "index_person"]
    df = pd.read_feather(data_path, columns=cols)
    logger.debug(f"{df.shape[0]:,} rows loaded")

    df.columns = df.columns.str.lower()
    df = df.rename(columns={"finregistryid": "personid"})

    df = df.loc[~df["personid"].isna()]
    df = df.drop_duplicates(subset=["personid"]).reset_index(drop=True)

    df["birth_year"] = to_decimal_year(df["date_of_birth"])
    df["death_year"] = to_decimal_year(df["death_date"])
    df = df.drop(columns=["date_of_birth", "death_date"])

    df["index_person"] = df["index_person"].astype(bool)

    df["female"] = np.nan
    df.loc[df["sex"] == SEX_FEMALE_MINIMAL_PHENOTYPE, "female"] = True
    df.loc[df["sex"] == SEX_MALE_MINIMAL_PHENOTYPE, "female"] = False
    df = df.drop(columns={"sex"})
    df = df.astype({"personid": "string[pyarrow]"})

    logger.info(f"{df.shape[0]:,} rows in minimal phenotype")

    return df


def load_endpoint_definitions_data(
    data_path=FINREGISTRY_ENDPOINT_DEFINITIONS_DATA_PATH,
):
    """
    Loads and applies the following steps to FinnGen endpoint definitions data:
    - rename columns
    - drop omitted endpoints 
    - replace `sex` with `female`
    
    Args:
        data_path (str, optional): file path of the FinnGen endpoint definitions csv file

    Returns:
        df (DataFrame): FinnGen endpoints dataframe
    """
    cols = ["NAME", "SEX", "OMIT"]
    df = pd.read_csv(
        data_path, sep=";", usecols=cols, skiprows=[1], encoding="latin1"
    )
    logger.debug(f"{df.shape[0]:,} rows loaded")

    df = df.rename(columns={"NAME": "endpoint", "SEX": "sex", "OMIT": "omit"})
    df = df.loc[df["omit"].isnull()]
    df = df.reset_index(drop=True)
    df["female"] = np.nan
    df.loc[df["sex"] == SEX_FEMALE_ENDPOINTS, "female"] = True
    df.loc[df["sex"] == SEX_MALE_ENDPOINTS, "female"] = False
    df = df.drop(columns=["omit", "sex"])
    logger.info(f"{df.shape[0]:,} rows in endpoint definitions")

    return df


def load_first_events_data(
    endpoints, minimal_phenotype, data_path=FINREGISTRY_DENSIFIED_FIRST_EVENTS_DATA_PATH
):
    """
    Loads and applies the following steps to first events data:
    - rename columns
    - remove endpoints not in endpoints dataset
    - add demographics from minimal phenotype
    - add the event year
    
    Args:
        data_path (str, optional): file path of the long (densified) first events feather file

    Returns:
        df (DataFrame): first events dataframe
    """
    cols = ["FINREGISTRYID", "ENDPOINT", "AGE"]
    df = pd.read_feather(data_path, columns=cols)
    df.columns = ["personid", "endpoint", "age"]

    logger.debug(f"{df.shape[0]:,} rows loaded")

    df = df.loc[df["endpoint"].isin(endpoints["endpoint"])].reset_index(drop=True)
    df = df.merge(minimal_phenotype, how="left", on="personid")
    df["year"] = df["birth_year"] + df["age"]
    df = df.astype({"personid": "string[pyarrow]", "endpoint": "category"})

    logger.info(f"{df.shape[0]:,} rows in first events")

    return df
