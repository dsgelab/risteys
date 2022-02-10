"""Functions for loading the FinRegistry datasets"""

import pandas as pd
import numpy as np
from risteys_pipeline.config import *
from risteys_pipeline.log import logger
from risteys_pipeline.utils import to_decimal_year

SEX_FEMALE = 1.0
SEX_MALE = 0.0


def load_minimal_phenotype_data(data_path=FINREGISTRY_MINIMAL_PHENOTYPE_DATA_PATH):
    """
    Loads and applies the following steps to minimal phenotype data:
    - drop rows with no FinRegistry ID
    - drop duplicated rows
    - add birth and death year
    - add `female`
    - replace numeric sex with strings
    - drop redundant columns (date_of_birth, death_date)
    
    Args:
        data_path (str, optional): file path of the minimal phenotype csv file

    Returns: 
        df (DataFrame): minimal phenotype dataframe
    """
    cols = ["FINREGISTRYID", "date_of_birth", "death_date", "sex"]
    df = pd.read_feather(data_path, columns=cols)
    logger.info(f"{df.shape[0]} rows loaded")
    df.columns = df.columns.str.lower()
    df = df.loc[~df["finregistryid"].isna()]
    df = df.drop_duplicates(subset=["finregistryid"]).reset_index(drop=True)
    df["birth_year"] = to_decimal_year(df["date_of_birth"])
    df["death_year"] = to_decimal_year(df["death_date"])
    df["female"] = df["sex"] == SEX_FEMALE
    df["sex"] = df["sex"].replace(
        {SEX_FEMALE: "female", SEX_MALE: "male", np.nan: "unknown"}
    )
    df = df.drop(columns=["date_of_birth", "death_date"])
    logger.info(f"{df.shape[0]} rows after data pre-processing")
    return df


def load_endpoints_data(data_path=FINREGISTRY_ENDPOINTS_DATA_PATH):
    """
    Loads and applies the following steps to FinnGen endpoints data:
    - rename columns
    - drop omitted endpoints 
    
    Args:
        data_path (str, optional): file path of the FinnGen endpoints csv file

    Returns:
        df (DataFrame): FinnGen endpoints dataframe
    """
    cols = ["NAME", "SEX", "OMIT"]
    df = pd.read_csv(data_path, sep=";", usecols=cols, header=0)
    logger.info(f"{df.shape[0]} rows loaded")
    df = df.rename(columns={"NAME": "endpoint", "SEX": "sex", "OMIT": "omit"})
    df = df.loc[df["omit"].isnull()].reset_index(drop=True)
    df = df.drop(columns=["omit"])
    logger.info(f"{df.shape[0]} rows after data pre-processing")
    return df


def load_first_events_data(
    endpoints, minimal_phenotype, data_path=FINREGISTRY_LONG_FIRST_EVENTS_DATA_PATH
):
    """
    Loads and applies the following steps to first events data:
    - rename columns
    - remove endpoints not in endpoints dataset
    - add demographics from minimal phenotype
    
    Args:
        data_path (str, optional): file path of the long (densified) first events feather file

    Returns:
        df (DataFrame): first events dataframe
    """
    cols = ["FINNGENID", "ENDPOINT", "AGE", "YEAR"]
    df = pd.read_feather(data_path, columns=cols)
    df.columns = ["finregistryid", "endpoint", "age", "year"]
    logger.info(f"{df.shape[0]} rows loaded")

    df = df.loc[df["endpoint"].isin(endpoints["endpoint"])]
    df = df.reset_index(drop=True)
    df = df.merge(minimal_phenotype, how="left", on="finregistryid")
    df = df.fillna({"sex": "unknown"})
    logger.info(f"{df.shape[0]} rows after data pre-processing")

    return df
