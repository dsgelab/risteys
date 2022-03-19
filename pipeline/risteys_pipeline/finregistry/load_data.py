"""Functions for loading the FinRegistry datasets"""

import pandas as pd
import numpy as np
from risteys_pipeline.config import *
from risteys_pipeline.log import logger
from risteys_pipeline.utils import to_decimal_year

SEX_FEMALE_ENDPOINTS = 2.0
SEX_MALE_ENDPOINTS = 1.0
SEX_FEMALE_MINIMAL_PHENOTYPE = 1.0
SEX_MALE_MINIMAL_PHENOTYPE = 0.0


def load_minimal_phenotype_data(data_path=FINREGISTRY_MINIMAL_PHENOTYPE_DATA_PATH):
    """
    Loads and applies the following steps to minimal phenotype data:
    - drop rows with no FinRegistry ID
    - drop duplicated rows
    - add birth and death year
    - drop redundant columns (date_of_birth, death_date)
    - set `index_person` to boolean
    - add `female`
    - replace numeric `sex` with strings
    
    Args:
        data_path (str, optional): file path of the minimal phenotype csv file

    Returns: 
        df (DataFrame): minimal phenotype dataframe
    """
    cols = ["FINREGISTRYID", "date_of_birth", "death_date", "sex", "index_person"]
    df = pd.read_feather(data_path, columns=cols)
    logger.info(f"{df.shape[0]} rows loaded")

    df.columns = df.columns.str.lower()

    df = df.loc[~df["finregistryid"].isna()]
    df = df.drop_duplicates(subset=["finregistryid"]).reset_index(drop=True)

    df["birth_year"] = to_decimal_year(df["date_of_birth"])
    df["death_year"] = to_decimal_year(df["death_date"])
    df = df.drop(columns=["date_of_birth", "death_date"])

    df["index_person"] = df["index_person"].astype(bool)

    df["female"] = pd.NA
    df.loc[df["sex"] == SEX_FEMALE_MINIMAL_PHENOTYPE, "female"] = True
    df.loc[df["sex"] == SEX_MALE_MINIMAL_PHENOTYPE, "female"] = False
    df["sex"] = df["sex"].replace(
        {
            SEX_FEMALE_MINIMAL_PHENOTYPE: "female",
            SEX_MALE_MINIMAL_PHENOTYPE: "male",
            np.nan: "unknown",
        }
    )

    logger.info(f"{df.shape[0]} rows after data pre-processing")

    return df


def load_endpoints_data(data_path=FINREGISTRY_ENDPOINTS_DATA_PATH):
    """
    Loads and applies the following steps to FinnGen endpoints data:
    - rename columns
    - drop omitted endpoints 
    - replace `sex` with `female`
    
    Args:
        data_path (str, optional): file path of the FinnGen endpoints csv file

    Returns:
        df (DataFrame): FinnGen endpoints dataframe
    """
    cols = ["NAME", "SEX", "OMIT"]
    df = pd.read_csv(data_path, sep=";", usecols=cols, skiprows=[1], encoding="latin1")
    logger.info(f"{df.shape[0]} rows loaded")
    df = df.rename(columns={"NAME": "endpoint", "SEX": "sex", "OMIT": "omit"})
    df = df.loc[df["omit"].isnull()].reset_index(drop=True)
    df["female"] = pd.NA
    df.loc[df["sex"] == SEX_FEMALE_ENDPOINTS, "female"] = True
    df.loc[df["sex"] == SEX_MALE_ENDPOINTS, "female"] = False
    df = df.drop(columns=["omit", "sex"])
    logger.info(f"{df.shape[0]} rows after data pre-processing")
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
    df.columns = ["finregistryid", "endpoint", "age"]
    logger.info(f"{df.shape[0]} rows loaded")

    df = df.loc[df["endpoint"].isin(endpoints["endpoint"])].reset_index(drop=True)
    df = df.merge(minimal_phenotype, how="left", on="finregistryid")
    df = df.fillna({"sex": "unknown"})
    df["year"] = df["birth_year"] + df["age"]
    logger.info(f"{df.shape[0]} rows after data pre-processing")

    return df
