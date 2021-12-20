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

    Returns a dataframe with the following columns: 
    finregistryid, start, stop, outcome, birth_year, weight, female
    """
    FOLLOWUP_DURATION = FOLLOWUP_END - FOLLOWUP_START

    outcome = df.copy()

    outcome["start"] = np.maximum(0, outcome["birth_year"] - FOLLOWUP_START)

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

    outcome["stop"] = np.minimum(outcome["death_year"], outcome["outcome_year"])
    outcome["stop"] = np.minimum(outcome["stop"], FOLLOWUP_END) - FOLLOWUP_START

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

    Returns a dataframe with the following columns:
    finregistryid, duration, exposure
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
    exposure["duration"] = exposure["exposure_year"] - FOLLOWUP_START

    cols = ["finregistryid", "duration", "exposure"]
    exposure = exposure[cols]

    return exposure


def build_cph_dataset(df):
    """
    Build the dataset for survival analysis using time-on-study as timescale.
    Exposure is modeled as a time-varying covariate.

    Input is a dataset with (at least) the following columns:
    finregistryid, birth_year, death_year, exposure_year, outcome_year, weight, female

    Returns a dataframe with the following columns: 
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


def survival_analysis(df):
    """
    Survival/mortality analysis with time-on-study as timescale.
    Analysis is only run if there's more than MIN_SUBJECTS subjects in exposed and unexposed cases and controls.
    Returns the hazard ratio between the outcome and exposure or None if there aren't enough subjects.
    """

    df_cph = build_cph_dataset(df)

    df_cph = df_cph.drop("finregistryid", axis=1)

    # Check that there's enough subjects in each cell
    min_subjects_check = (
        pd.crosstab(df_cph["outcome"], df_cph["exposure"]).values.min() > MIN_SUBJECTS
    )

    if min_subjects_check:
        logger.info("Fitting Cox PH model")
        cph = CoxPHFitter()
        cph.fit(
            df_cph,
            entry_col="start",
            duration_col="stop",
            event_col="outcome",
            weights_col="weight",
            robust=True,
        )
        cph.print_summary()
        hr = cph.hazard_ratios_[0]
    else:
        logger.info("Not enough subjects")
        hr = None

    return hr
