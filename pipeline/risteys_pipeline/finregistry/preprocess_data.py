"""Functions for preprocessing FinRegistry data"""

import numpy as np
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

    Args:
        minimal_phenotype (dataframe): minimal phenotype dataset with the following columns included: 
        birth_year, death_year, finregistryid, sex

    Returns:
        excluded_subjects (list): finregistryids of the excluded subjects
    """
    born_after_followup_end = minimal_phenotype["birth_year"] >= FOLLOWUP_END
    dead_before_followup_start = minimal_phenotype["death_year"] <= FOLLOWUP_START
    id_missing = minimal_phenotype["finregistryid"].isna()
    sex_missing = minimal_phenotype["sex"].isna()
    exclude = (
        born_after_followup_end | dead_before_followup_start | id_missing | sex_missing
    )
    excluded_subjects = minimal_phenotype.loc[exclude, "finregistryid"].tolist()
    logger.info(
        f"{len(excluded_subjects)} excluded subjects (born after follow-up: {sum(born_after_followup_end)}, dead before follow-up: {sum(dead_before_followup_start)}, id missing: {sum(id_missing)}, sex missing: {sum(sex_missing)})"
    )
    return excluded_subjects


def preprocess_endpoints_data(df):
    """Applies the following preprocessing steps to endpoints data: 
        - lowercase column names
        - exclude omitted endpoints and drop the "omit" column

    Args:
        df (DataFrame): endpoints dataframe

    Returns:
        df (DataFrame): endpoints dataframe with the following columns: endpoint, sex
    """
    logger.info("Preprocessing endpoints data")
    df = df.rename(columns={"NAME": "endpoint", "SEX": "sex", "OMIT": "omit"})
    df = df.loc[df["omit"].isnull()].reset_index(drop=True)
    df = df.drop(columns=["omit"])
    logger.info(f"{df.shape[0]} rows after data pre-processing")

    return df


def preprocess_first_events_data(df):
    """Applies the following preprocessing steps to first events data:
        - rename columns
        - drop events outside study timeframe

    Args:
        df (DataFrame): long first events dataframe

    Returns 
        df (DataFrame): long first events dataframe with the following columns:
        finregistryid, endpoint, age, year
    """
    df.columns = ["finregistryid", "endpoint", "age", "year"]
    df = df.loc[(df["year"] >= FOLLOWUP_START) & (df["year"] <= FOLLOWUP_END)]
    df = df.reset_index(drop=True)
    return df


def merge_first_events_data_with_minimal_phenotype(first_events, minimal_phenotype):
    """Merge first events data with minimal phenotype"""
    first_events = first_events.merge(minimal_phenotype, how="left", on="finregistryid")
    return first_events


def preprocess_exposure_and_outcome_data(df):
    """Applies the following preprocessing steps to exposure and outcome data:
        - rename columns
        - remove duplicated finregistryids
        - replace numeric event columns (e.g. <outcome>_NEVT) with numeric boolean (1=yes, 0=no)
        - replace endpoint ages (e.g. <outcome>_AGE) with NaN when the subject did not experience the endpoint

    Args:
        df (DataFrame): exposure and outcome dataframe

    Returns:
        df (DataFrame): exposure and outcome dataframe with the following columns: 
        finregistryid, exposure, exposure_age, outcome, outcome_age
    """
    df.columns = [
        "finregistryid",
        "exposure",
        "exposure_age",
        "outcome",
        "outcome_age",
    ]
    df = df.drop_duplicates(subset=["finregistryid"]).reset_index(drop=True)
    df["exposure"] = (df["exposure"] > 0).astype(int)
    df["outcome"] = (df["outcome"] > 0).astype(int)
    df["exposure_age"] = np.where(df["exposure"] == 1, df["exposure_age"], np.nan)
    df["outcome_age"] = np.where(df["outcome"] == 1, df["outcome_age"], np.nan)
    logger.info(f"{df.shape[0]} rows after data pre-processing")
    return df


def preprocess_minimal_phenotype_data(df):
    """Applies the following preprocessing steps to minimal phenotype data:
        - lowercase column names 
        - drop duplicated rows
        - add birth and death year
        - drop excluded subjects
        - add indicator for females (bool)

    Args:
        df (DataFrame): minimal phenotype dataframe

    Returns:
        df (DataFrame): minimal phenotype dataframe with the following columns: 
        finregistryid, date_of_birth, death_date, sex, death_age, dead, female
    """
    df.columns = df.columns.str.lower()
    df = df.drop_duplicates(subset=["finregistryid"]).reset_index(drop=True)
    df["birth_year"] = (
        df["date_of_birth"].dt.year
        + (df["date_of_birth"].dt.dayofyear - 1) / DAYS_IN_YEAR
    )
    df["death_year"] = (
        df["death_date"].dt.year + (df["death_date"].dt.dayofyear - 1) / DAYS_IN_YEAR
    )
    df["female"] = df["sex"] == SEX_FEMALE
    excluded_subjects = list_excluded_subjects(df)
    df = df.loc[~df["finregistryid"].isin(excluded_subjects)]

    logger.info(f"{df.shape[0]} rows after data pre-processing")

    return df


def merge_exposure_and_outcome_with_minimal_phenotype(
    exposure_and_outcome, minimal_phenotype
):
    """Merge exposure and outcome dataset with minimal phenotype data and calculate exposure and outcome years.
    Only subjects in both datasets are included (inner join).

    Args:
        exposure_and_outcome (DataFrame): preprocessed exposure and outcome dataframe
        minimal_phenotype (DataFrame): preprocessed minimal phenotype dataframe

    Returns:
        df (DataFrame): merged dataframe with the following columns: 
        finregistryid, female, birth_year, death_year, exposure_age, exposure_year, outcome_age, outcome_year
    """
    df = minimal_phenotype.merge(exposure_and_outcome, how="inner", on="finregistryid")

    df["exposure_year"] = df["birth_year"] + df["exposure_age"]
    df["outcome_year"] = df["birth_year"] + df["outcome_age"]

    cols = [
        "finregistryid",
        "female",
        "birth_year",
        "death_year",
        "exposure_age",
        "exposure_year",
        "outcome_age",
        "outcome_year",
    ]

    df = df[cols]

    return df
