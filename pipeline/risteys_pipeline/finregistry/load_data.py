"""Functions for loading the FinRegistry datasets"""

import pandas as pd
from risteys_pipeline.config import *
from risteys_pipeline.log import logger
from risteys_pipeline.utils import to_decimal_year

SEX_FEMALE = 1.0


def load_minimal_phenotype_data(data_path=FINREGISTRY_MINIMAL_PHENOTYPE_DATA_PATH):
    """
    Loads and lightly preprocesses minimal phenotype data
    - drop rows with no FinRegistry ID
    - drop duplicated rows
    - add birth and death year
    - add `female`
    
    Args:
        data_path (str, optional): file path of the minimal phenotype csv file
        preprocessing (bool, optional): will the data be preprocessed 

    Returns: 
        df (DataFrame): minimal phenotype dataframe
    """
    cols = ["FINREGISTRYID", "date_of_birth", "death_date", "sex"]
    dtypes = {
        "FINREGISTRYID": str,
        "date_of_birth": str,
        "death_date": str,
        "sex": float,  # NAs are not allowed for int in pandas
    }
    date_cols = ["date_of_birth", "death_date"]
    df = pd.read_csv(data_path, usecols=cols, dtype=dtypes, parse_dates=date_cols)
    logger.info(f"{df.shape[0]} rows loaded")
    df.columns = df.columns.str.lower()
    df = df.loc[~df["finregistryid"].isna()]
    df = df.drop_duplicates(subset=["finregistryid"]).reset_index(drop=True)
    df["birth_year"] = to_decimal_year(df["date_of_birth"])
    df["death_year"] = to_decimal_year(df["death_year"])
    df["female"] = df["sex"] == SEX_FEMALE
    logger.info(f"{df.shape[0]} rows after data pre-processing")
    return df


def load_first_events_data(data_path=FINREGISTRY_LONG_FIRST_EVENTS_DATA_PATH):
    """Loads the long first events data
    
    Args:
        data_path (str, optional): file path of the long first events feather file
        preprocess (bool, optional): will the data be preprocessed

    Returns:
        df (DataFrame): long first events dataframe
    """
    cols = ["FINNGENID", "ENDPOINT", "AGE", "YEAR"]
    df = pd.read_feather(data_path, columns=cols)
    df.columns = ["finregistryid", "endpoint", "age", "year"]
    return df


def load_endpoints_data(data_path=FINREGISTRY_ENDPOINTS_DATA_PATH):
    """
    Loads and lightly preprocesses endpoints data as a dataframe.
    - rename columns
    - drop omitted endpoints 
    
    Args:
        data_path (str, optional): file path of the FinnGen endpoints excel file

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
