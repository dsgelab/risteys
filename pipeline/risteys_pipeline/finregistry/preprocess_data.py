"""Functions for preprocessing FinRegistry data"""

import pandas as pd
from risteys_pipeline.log import logger
from risteys_pipeline.config import FOLLOWUP_START, FOLLOWUP_END

DAYS_IN_YEAR = 365.25
SEX_FEMALE = 2


def list_excluded_subjects(minimal_phenotype):
    """List subjects who should be excluded from the analyses based on the following criteria: 
        - born after the end of the follow-up
        - died before the start of the follow-up
        - missing finregistryid
        - missing sex

        Returns a list of finregistryids.
    """
    logger.info("Finding subjects to be excluded")
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
    logger.info("Preprocessing endpoints data")
    df = df.rename(columns={"NAME": "endpoint", "SEX": "sex", "OMIT": "omit"})
    df = df.loc[df["omit"].isnull()].reset_index(drop=True)
    df = df.drop(columns=["omit"])

    return df


def preprocess_wide_first_events_data(df):
    """Applies the following preprocessing steps to wide first events data:
        - rename columns
        - remove duplicated finregistryids

        Returns a dataframe with the following columns: 
        finregistryid, endpoint, age, year

        TODO: make sure column order is retained
    """
    logger.info("Preprocessing wide first events data")
    df.columns = [
        "finregistryid",
        "exposure",
        "exposure_age",
        "exposure_year",
        "outcome",
        "outcome_age",
        "outcome_year",
    ]
    df = df.drop_duplicates(subset=["finregistryid"]).reset_index(drop=True)

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
        finregistryid, date_of_birth, death_date, sex, death_age, dead, female
    """
    logger.info("Preprocessing minimal phenotype data")
    df.columns = df.columns.str.lower()
    df = df.drop_duplicates().reset_index(drop=True)
    excluded_subjects = list_excluded_subjects(df)
    df = df.loc[~df["finregistryid"].isin(excluded_subjects)]
    df["death_age"] = (df["death_date"] - df["date_of_birth"]).dt.days / DAYS_IN_YEAR
    df["dead"] = ~df["death_date"].isna()
    df["female"] = df["sex"] == SEX_FEMALE

    return df
