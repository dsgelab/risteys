"""Functions for preprocessing FinRegistry data"""

import pandas as pd
from risteys_pipeline.log import logger


def preprocess_endpoints_data(df):
    """Applies the following preprocessing steps to endpoints data: 
        - lowercase column names
        - exclude omitted endpoints and drop the "omit" column

        Returns a dataframe with the following columns: 
        endpoint, sex
    """
    df = df.rename(columns={"NAME": "endpoint", "SEX": "sex", "OMIT": "omit"})
    df = df[df["omit"].isnull()].reset_index(drop=True)
    df = df.drop(columns=["omit"])

    return df


def preprocess_first_events_data(df):
    """Applies the following preprocessing steps to first events data: 
        - lowercase columns names
        - rename fingenid to finregistryid
        - drop duplicated rows
        - TODO: exclude subjects who died before the start of the follow-up
        - TODO: exclude subjects who were born after the end of the follow-up
        
        Returns a dataframe with the following columns: 
        finregistryid, endpoint, age, year, nevt
    """
    df.columns = df.columns.str.lower()
    df = df.rename(columns={"finngenid": "finregistryid"})
    df = df.drop_duplicates().reset_index(drop=True)
    df = df.dropna(subset=["finregistryid"])

    return df


def preprocess_minimal_phenotype_data(df):
    """Applies the following preprocessing steps to minimal phenotype data:
        - lowercase column names 
        - drop duplicated rows 
        - remove subjects with missing ID or sex
        - add female column (bool)
        - add year of birth (num)
        - add indicator for dead subjects (bool)
        - add approximate death age (num)
        - TODO: exclude subjects who died before the start of the follow-up
        - TODO: exclude subjects who were born after the end of the follow-up

        Returns a dataframe with the following columns: 
        finregistryid, date_of_birth, death_date, sex, birth_year, death_year, death_age, dead, female
    """
    df.columns = df.columns.str.lower()
    df = df.drop_duplicates().reset_index(drop=True)
    df = df.dropna(subset=["finregistryid", "sex"])
    df["female"] = df["sex"] == 2
    df["birth_year"] = df["date_of_birth"].dt.year
    df["dead"] = ~df["death_date"].isna()
    df["death_age"] = (df["death_date"] - df["date_of_birth"]).dt.days / 365.25
