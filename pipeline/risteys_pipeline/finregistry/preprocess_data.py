"""Functions for preprocessing FinRegistry data"""

import pandas as pd
from risteys_pipeline.log import logger
from risteys_pipeline.config import FOLLOWUP_START, FOLLOWUP_END


def list_excluded_subjects(minimal_phenotype):
    """
    List subjects who should be excluded from the analyses based on the following criteria: 
        - born after the end of the follow-up
        - died before the start of the follow-up
        - missing finregistryid
        - missing sex
    """
    birth_year = minimal_phenotype["date_of_birth"].dt.year
    death_year = minimal_phenotype["death_year"].dt.year
    id_missing = minimal_phenotype["FINREGISTRYID"].isna()
    sex_missing = minimal_phenotype["SEX"].isna()
    exclude = (
        (birth_year >= FOLLOWUP_END)
        | (death_year <= FOLLOWUP_START)
        | id_missing
        | sex_missing
    )
    excluded_subjects = minimal_phenotype.loc[exclude, "FINREGISTRYID"].tolist()
    return excluded_subjects


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


def preprocess_wide_first_events_data(df, excluded_subjects):
    """Applies the following preprocessing steps to wide first events data:
        - rename columns
        - drop excluded subjects
    """
    df.columns = ["finregistryid", "endpoint", "age", "year"]
    df = df[~df["finregistryid"].isin(excluded_subjects)]

    return df


def preprocess_minimal_phenotype_data(df, excluded_subjects):
    """Applies the following preprocessing steps to minimal phenotype data:
        - lowercase column names 
        - drop duplicated rows 
        - drop excluded subjects
        - add indicator for dead subjects (bool)
        - add indicator for females (bool)
        - add approximate death age (num)

        Returns a dataframe with the following columns: 
        finregistryid, date_of_birth, death_date, sex, birth_year, death_year, death_age, dead, female
    """
    df.columns = df.columns.str.lower()

    df = df.drop_duplicates().reset_index(drop=True)

    excluded_subjects = list_excluded_subjects(df)
    df = df[~df["finregistryid"].isin(excluded_subjects)]

    df["death_age"] = (df["death_date"] - df["date_of_birth"]).dt.days / 365.25
    df["dead"] = ~df["death_date"].isna()
    df["female"] = df["sex"] == 2

    return df
