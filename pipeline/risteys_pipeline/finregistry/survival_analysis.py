"""Functions for survival analysis"""

import pandas as pd
from lifelines import CoxPHFitter
from lifelines.utils import add_covariate_to_timeline
from risteys_pipeline.log import logger
from risteys_pipeline.config import (
    FOLLOWUP_START,
    MIN_SUBJECTS_PERSONAL_DATA,
)
from risteys_pipeline.finregistry.sample import (
    get_cases,
    get_controls,
    get_exposed,
    calculate_case_cohort_weights,
)

N_CASES = 25_000
CONTROLS_PER_CASE = 4
MIN_SUBJECTS_SURVIVAL_ANALYSIS = 100


def build_cph_dataset(outcome, exposure, cohort, first_events):
    """
    Build a dataset for fitting a Cox PH model.
    Exposure is included as a time-varying covariate if present.

    Args:
        outcome (str): outcome endpoint 
        exposure (str): exposure endpoint (None if there's no exposure)
        cohort (DataFrame): cohort for sampling controls 
        first_events (DataFrame): first events dataset

    Returns:
        df_cph (DataFrame): dataset with the following columns:
        finregistryid, start, stop, exposure, outcome, birth_year, female, weight
    """
    cases = get_cases(first_events, outcome, n_cases=N_CASES)
    controls = get_controls(cohort, CONTROLS_PER_CASE * cases.shape[0])

    weight_cases, weight_controls = calculate_case_cohort_weights(
        cases["finregistryid"],
        controls["finregistryid"],
        cases["finregistryid"],
        cohort["finregistryid"],
    )
    cases["weight"] = weight_cases
    controls["weight"] = weight_controls

    df_cph = pd.concat([cases, controls])
    df_cph = df_cph.reset_index(drop=True)

    if exposure:
        df_cph["finregistryid_unique"] = (
            df_cph["finregistryid"] + "_" + df_cph["outcome"].map(str)
        )
        exposed = get_exposed(first_events, exposure, cases)
        exposed = exposed.merge(
            df_cph[["finregistryid", "finregistryid_unique"]],
            how="left",
            on="finregistryid",
        )
        df_cph = add_covariate_to_timeline(
            df_cph.drop(columns=["finregistryid"]),
            exposed,
            id_col="finregistryid_unique",
            duration_col="duration",
            event_col="outcome",
        )
        df_cph = df_cph.reset_index(drop=True)

    df_cph = df_cph.drop(columns=["death_year"])
    df_cph = df_cph.loc[df_cph["start"] < df_cph["stop"]]
    df_cph = df_cph.reset_index(drop=True)

    return df_cph


def check_min_number_of_subjects(df_cph):
    """
    Check that the requirement for the minimum number of subjects is met.
    The minimum number of subjects for the survival analysis cannot bypass the 
    minimum person requirement of personal data usage.

    Args:
        df_cph (DataFrame): output of build_cph_dataset

    Returns:
        check (bool): True if there's enough subjects, otherwise False
    """
    min_subjects = max(MIN_SUBJECTS_SURVIVAL_ANALYSIS, MIN_SUBJECTS_PERSONAL_DATA)
    if "exposure" in df_cph.columns:
        tbl = pd.crosstab(
            df_cph["outcome"],
            df_cph["exposure"],
            values=df_cph["finregistryid"],
            aggfunc=pd.Series.nunique,
        )
    else:
        tbl = df_cph.groupby("outcome")["finregistryid"].nunique()
    check = tbl.values.min() > min_subjects
    return check


def survival_analysis(df_cph, timescale="time-on-study"):
    """
    Fit a Cox PH model to the data. 
    The model is only fitted if the requirement for the minimum number of participants is met.

    Args: 
        df_cph (DataFrame): output of build_cph_dataset()
        timescale (str): "time-on-study" (default) or "age"

    Returns: 
        cph (CoxPHFitter): fitted Cox PH model. None if there's not enough subjects.
    """

    check = check_min_number_of_subjects(df_cph)

    if not check:
        logger.info("Not enough subjects")
        cph = None
    else:
        df_cph = df_cph.drop(columns=["finregistryid"])

        if timescale == "age":
            df_cph["start"] = df_cph["start"] - df_cph["birth_year"]
            df_cph["end"] = df_cph["end"] - df_cph["birth_year"]

        logger.info("Fitting the Cox PH model")
        cph = CoxPHFitter()
        cph.fit(
            df_cph,
            entry_col="start",
            duration_col="stop",
            event_col="outcome",
            weights_col="weight",
            robust=True,
        )

    return cph
