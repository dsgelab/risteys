"""Functions for survival analyses"""

import pandas as pd
import numpy as np

from lifelines import CoxPHFitter

from lifelines.utils import add_covariate_to_timeline
from risteys_pipeline.config import FOLLOWUP_START, FOLLOWUP_END
from risteys_pipeline.log import logger

MIN_SUBJECTS = 100


def build_outcome_dataset(df):
    """
    Build the outcome dataset for Cox proportional hazard model.
    Outcomes before the start of the follow-up and after the end of the follow-up are omitted.

    Args:
        df (DataFrame): dataframe with the following columns: 
        finregistryid, birth_year, death_year, outcome_year, weight, female
        timescale (bool): timescale for Cox regression, either time-on-study or age

    Returns:
        outcome (DataFrame): outcome dataframe with the following columns: 
        finregistryid, start, stop, outcome, birth_year, weight, female
    """

    outcome = df.copy()

    # Exclude outcomes outside follow-up timeframe
    outcome["outcome"] = (
        outcome["outcome_year"]
        .between(FOLLOWUP_START, FOLLOWUP_END, inclusive="both")
        .astype(int)
    )
    outcome["outcome_year"] = np.where(
        outcome["outcome"] == 1, outcome["outcome_year"], np.nan
    )

    # Fill missing years with Inf (needed for min/max)
    outcome = outcome.fillna({"outcome_year": np.Inf, "death_year": np.Inf})

    # Start and stop year
    n = outcome.shape[0]
    start_year = np.maximum.reduce([[FOLLOWUP_START] * n, outcome["birth_year"].values])
    stop_year = np.minimum.reduce(
        [
            outcome["death_year"].values,
            outcome["outcome_year"].values,
            [FOLLOWUP_END] * n,
        ]
    )

    outcome["start"] = start_year - FOLLOWUP_START
    outcome["stop"] = stop_year - FOLLOWUP_START

    cols = [
        "finregistryid",
        "start",
        "stop",
        "outcome",
        "birth_year",
        "weight",
        "female",
    ]
    outcome = outcome[cols]

    return outcome


def build_exposure_dataset(df):
    """
    Build the exposure dataset for modeling exposure as a time-varying covariate.
    Exposures before the start of the follow-up, after the end of the follow-up, and after the outcome are omitted.

    Args: 
        df (DataFrame): dataframe with the following columns: 
        finregistryid, birth_year, exposure_year, outcome_year
        timescale (bool): timescale for Cox regression, either time-on-study or age

    Returns:
        exposure (DataFrame): exposure dataframe with the following columns:
        finregistryid, duration, exposure
    """
    exposure = df.copy()

    # Exclude exposures occuring outside the study timeframe or after outcome
    before_outcome = exposure["exposure_year"] <= exposure["outcome_year"].fillna(
        np.Inf
    )
    inside_timeframe = exposure["exposure_year"].between(
        FOLLOWUP_START, FOLLOWUP_END, inclusive="both"
    )
    exposure = exposure[before_outcome & inside_timeframe].reset_index(drop=True)

    # Calculate duration for both time-on-study and age as timescale
    exposure["duration"] = exposure["exposure_year"] - FOLLOWUP_START
    exposure["exposure"] = 1

    cols = ["finregistryid", "duration", "exposure"]
    exposure = exposure[cols]

    return exposure


def build_cph_dataset(df, timescale):
    """
    Build the dataset for survival analysis using time-on-study or age as timescale.
    Exposure is modeled as a time-varying covariate.

    Args:
        df (DataFrame): dataframe with the following columns:
        finregistryid, birth_year, death_year, exposure_year, outcome_year, weight, female
        timescale (bool): timescale for Cox regression, either time-on-study or age

    Returns:
        res (DataFrame): a dataframe with the following columns: 
        start, stop, outcome, exposure, birth_year, weight, female

    """
    # Copy dataframe
    df = df.copy()

    # Add case/control identifier to finregistryids as the same individual may be in both cases and controls
    df["finregistryid"] = df["finregistryid"].map(str) + df["case"].map(str)

    # Create dataframes for exposure and outcome
    exposure = build_exposure_dataset(df)
    outcome = build_outcome_dataset(df)

    # Combine datasets
    res = add_covariate_to_timeline(
        outcome,
        exposure,
        id_col="finregistryid",
        duration_col="duration",
        event_col="outcome",
    )

    # Change time-on-study to age if timescale is age
    if timescale == "age":
        res["start"] = res["start"] - res["birth_year"] + FOLLOWUP_START
        res["stop"] = res["stop"] - res["birth_year"] + FOLLOWUP_START

    # Add exposure if missing
    if "exposure" not in res:
        res["exposure"] = np.nan

    # Drop rows where start >= stop
    start_after_stop = res["start"] >= res["stop"]
    res = res.loc[~start_after_stop].reset_index(drop=True)
    logger.info(f"{sum(start_after_stop)} rows had start >= stop")

    # Change data types
    res["exposure"] = res["exposure"].fillna(0).astype(int)
    res["outcome"] = res["outcome"].astype(int)

    return res


def survival_analysis(df, timescale="time-on-study"):
    """
    Survival/mortality analysis with time-on-study or age as timescale.
    Analysis is only run if there's more than MIN_SUBJECTS subjects in exposed and unexposed cases and controls.

    Args: 
        df (DataFrame): dataframe with the following columns:
        finregistryid, birth_year, death_year, exposure_year, outcome_year, weight, female
        timescale (bool, optional): timescale for Cox regression, either time-on-study or age. Defaults to time-on-study.

    Returns:
        cph (Object): fitted Cox Proportional Hazard model object. None if there aren't enough subjects.
    """

    df_cph = build_cph_dataset(df, timescale)

    # Check that there's enough subjects in each cell
    # Unique finregistryids are counted, so the last char representing the case/control group is dropped
    min_subjects_check = (
        pd.crosstab(
            df_cph["outcome"],
            df_cph["exposure"],
            values=df_cph["finregistryid"].str[:-1],
            aggfunc=pd.Series.nunique,
        ).values.min()
        > MIN_SUBJECTS
    )

    if min_subjects_check:
        logger.info("Fitting Cox PH model")
        df_cph = df_cph.drop("finregistryid", axis=1)
        cph = CoxPHFitter()
        cph.fit(
            df_cph,
            entry_col="start",
            duration_col="stop",
            event_col="outcome",
            weights_col="weight",
            robust=True,
        )
    else:
        logger.info("Not enough subjects")
        cph = None

    return cph
