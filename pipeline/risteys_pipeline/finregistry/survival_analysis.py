"""Functions for survival analysis"""

import pandas as pd
from lifelines import CoxPHFitter
from lifelines.utils import add_covariate_to_timeline
from risteys_pipeline.log import logger
from risteys_pipeline.config import (
    FOLLOWUP_END,
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


def prep_all_cases(first_events, cohort):
    """
    Prep all cases for survival analysis
    - drop endpoints outside study timeframe
    - drop IDs not included in the cohort
    
    Args:
        first_events (DataFrame): first events dataset
        cohort (DataFrame): cohort dataset, output of get_cohort()

    Returns:
        all_cases (DataFrame)
    """
    logger.info("Prepping all cases")
    all_cases = first_events.copy()

    inside_timeframe = (all_cases["birth_year"] + all_cases["age"]).between(
        FOLLOWUP_START, FOLLOWUP_END
    )
    all_cases = all_cases.loc[inside_timeframe].reset_index(drop=True)

    cohortids = cohort["finregistryid"]
    all_cases = all_cases.merge(cohortids, how="right", on="finregistryid")
    all_cases = all_cases.reset_index(drop=True)

    return all_cases


def build_cph_dataset(outcome, exposure, cohort, all_cases):
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
        finregistryid, start (year), stop (year), exposure, outcome, birth_year, female, weight
    """
    cases = get_cases(all_cases, outcome, n_cases=N_CASES)
    n_cases = cases.shape[0]

    df_cph = None

    if n_cases > 0:
        controls = get_controls(cohort, CONTROLS_PER_CASE * n_cases)

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
            exposed = get_exposed(all_cases, exposure, cases)
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

        df_cph["female"] = df_cph["female"].astype(int)
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


def survival_analysis(
    df_cph, timescale="time-on-study", drop_sex=False, stratify_by_sex=False
):
    """
    Fit a Cox PH model to the data. 
    The model is only fitted if the requirement for the minimum number of participants is met.

    Args: 
        df_cph (DataFrame): output of build_cph_dataset()
        timescale (str): "time-on-study" (default) or "age"
        drop_sex (bool): should sex be dropped from covariates
        stratify_by_age (bool): should the analysis be stratified by sex

    Returns: 
        cph (CoxPHFitter): fitted Cox PH model. None if there's not enough subjects.
    """

    cph = None

    if df_cph is not None:

        check = check_min_number_of_subjects(df_cph)

        if not check:
            logger.info("Not enough subjects")
            cph = None
        else:
            df_timescale = df_cph.copy()

            # Set timescale
            if timescale == "time-on-study":
                df_timescale["stop"] = df_timescale["stop"] - df_timescale["start"]
                df_timescale = df_timescale.drop(columns=["start"])
                entry_col = None
            elif timescale == "age":
                df_timescale["start"] = df_timescale["start"] - df_timescale["birth_year"]
                df_timescale["stop"] = df_timescale["stop"] - df_timescale["birth_year"]
                entry_col = "start"

            # Drop sex if specified
            if drop_sex:
                df_timescale = df_timescale.drop(columns=["female"])

            # Set strata if specified
            strata = ["female"] if stratify_by_sex == True else None

            # Drop FinRegistry IDs
            df_timescale = df_timescale.drop(columns=["finregistryid"])

            # Fit the model
            logger.info("Fitting the Cox PH model")
            cph = CoxPHFitter()
            cph.fit(
                df_timescale,
                entry_col=entry_col,
                duration_col="stop",
                event_col="outcome",
                strata=strata,
                weights_col="weight",
                robust=True,
            )

    return cph