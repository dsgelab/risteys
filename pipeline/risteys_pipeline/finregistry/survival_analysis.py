"""Functions for survival analyses"""

import pandas as pd
import numpy as np

from lifelines import CoxPHFitter

from lifelines.utils import add_covariate_to_timeline
from risteys_pipeline.config import FOLLOWUP_START, FOLLOWUP_END
from risteys_pipeline.log import logger

MIN_SUBJECTS = 100


def build_outcome_dataset(df, timescale):
    """
    Build the outcome dataset for Cox proportional hazard model.
    Outcomes before the start of the follow-up and after the end of the follow-up are omitted.

    Args:
        df (DataFrame): dataframe with the following columns: 
        finregistryid, birth_year, death_year, outcome_age, weight, female
        timescale (bool): timescale for Cox regression, either time-on-study or age


    Returns:
        outcome (DataFrame): outcome dataframe with the following columns: 
        finregistryid, start, stop, outcome, birth_year, weight, female

    TODO: outcome_year already calculated in merge_first_events_with_minimal_phenotype()
    TODO: remove timescale and always add both (start_time, end_time) and (start_age, end_age)
    """

    outcome = df.copy()

    outcome["outcome_year"] = outcome["birth_year"] + outcome["outcome_age"]

    outcome["outcome"] = (
        outcome["outcome_year"]
        .between(FOLLOWUP_START, FOLLOWUP_END, inclusive="both")
        .astype(int)
    )

    outcome["outcome_year"] = np.where(
        outcome["outcome"] == 1, outcome["outcome_year"], np.nan
    )

    outcome = outcome.fillna({"outcome_year": np.Inf, "death_year": np.Inf})

    if timescale == "time-on-study":
        start = np.maximum(0, outcome["birth_year"] - FOLLOWUP_START)
        stop = np.minimum(outcome["death_year"], outcome["outcome_year"])
        stop = np.minimum(stop, FOLLOWUP_END) - FOLLOWUP_START
    if timescale == "age":
        start = np.maximum(0, FOLLOWUP_START - outcome["birth_year"])
        stop = np.minimum(
            outcome["death_year"] - outcome["birth_year"],
            outcome["outcome_year"] - outcome["birth_year"],
        )
        stop = np.minimum(stop, FOLLOWUP_END - outcome["birth_year"])

    outcome["start"] = start
    outcome["stop"] = stop

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


def build_exposure_dataset(df, timescale):
    """
    Build the exposure dataset for modeling exposure as a time-varying covariate.
    Exposures before the start of the follow-up, after the end of the follow-up, and after the outcome are omitted.

    Args: 
        df (DataFrame): dataframe with the following columns: 
        finregistryid, birth_year, death_year, outcome_age, exposure_age
        timescale (bool): timescale for Cox regression, either time-on-study or age

    Returns:
        exposure (DataFrame): exposure dataframe with the following columns:
        finregistryid, duration, exposure

    TODO: outcome_year and exposure_year already calculated in merge_first_events_with_minimal_phenotype()
    TODO: remove timescale and always add both duration_time and duration_age
    """
    cols = [
        "finregistryid",
        "birth_year",
        "death_year",
        "outcome_age",
        "exposure_age",
    ]
    exposure = df[cols].reset_index(drop=True)

    exposure["outcome_year"] = exposure["birth_year"] + exposure["outcome_age"]
    exposure["exposure_year"] = exposure["birth_year"] + exposure["exposure_age"]

    exposure = exposure.fillna({"outcome_year": np.Inf, "exposure_year": np.Inf})

    exposure_before_followup_start = exposure["exposure_year"] <= FOLLOWUP_START
    exposure_after_followup_end = exposure["exposure_year"] >= FOLLOWUP_END
    exposure_after_outcome = exposure["exposure_year"] >= exposure["outcome_year"]

    exposure = exposure.loc[
        ~exposure_before_followup_start
        & ~exposure_after_followup_end
        & ~exposure_after_outcome
    ]
    exposure = exposure.reset_index(drop=True)

    exposure["exposure"] = 1

    if timescale == "time-on-study":
        duration = exposure["exposure_year"] - FOLLOWUP_START
    if timescale == "age":
        duration = exposure["exposure_age"]

    exposure["duration"] = duration

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

    TODO: handle timescales here instead of in build_exposure_dataset and build_outcome_dataset
    """
    # Copy dataframe
    df = df.copy()

    # Add case/control identifier to finregistryids as the same individual may be in both cases and controls
    df["finregistryid"] = df["finregistryid"].map(str) + df["case"].map(str)

    # Create dataframes for exposure and outcome
    exposure = build_exposure_dataset(df, timescale)
    outcome = build_outcome_dataset(df, timescale)

    # Combine datasets
    res = add_covariate_to_timeline(
        outcome,
        exposure,
        id_col="finregistryid",
        duration_col="duration",
        event_col="outcome",
    )

    # Add exposure if missing
    if "exposure" not in res:
        res["exposure"] = np.nan

    # Drop rows where start >= stop
    start_after_stop = res["start"] >= res["stop"]
    res = res.loc[~start_after_stop]
    logger.info(f"{sum(start_after_stop)} rows had start >= stop")

    # Change data types
    res["exposure"] = res["exposure"].fillna(0)
    res["exposure"] = res["exposure"].astype(int)
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
