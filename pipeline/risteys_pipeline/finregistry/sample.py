"""Functions for sampling the data"""

import numpy as np
from risteys_pipeline.log import logger
from risteys_pipeline.config import FOLLOWUP_START, FOLLOWUP_END


def get_cohort(minimal_phenotype):
    """
    Get cohort dataset with the following eligibility criteria:
        - born before the end of the follow-up
        - either not dead or died after the start of the follow-up
        - sex information is not missing

    Args:
        minimal_phenotype (DataFrame): minimal phenotype dataset

    Returns:
        cohort (DataFrame): cohort dataset with the following columns:
        finregistryid, birth_year, female, start, stop, outcome
    """
    cols = ["finregistryid", "birth_year", "death_year", "female"]
    cohort = minimal_phenotype[cols]

    born_before_fu_end = cohort["birth_year"] <= FOLLOWUP_END
    not_dead = minimal_phenotype["death_year"].isna()
    died_after_fu_start = minimal_phenotype["death_year"] >= FOLLOWUP_START
    inside_timeframe = born_before_fu_end & (not_dead | died_after_fu_start)
    cohort = cohort.loc[inside_timeframe]
    cohort = cohort.loc[~cohort["female"].isna()]

    cohort["start"] = np.maximum(cohort["birth_year"], FOLLOWUP_START)
    cohort["stop"] = np.minimum(cohort["death_year"].fillna(np.Inf), FOLLOWUP_END)
    cohort["outcome"] = 0
    cohort = cohort.drop(columns=["death_year"])

    return cohort


def get_controls(cohort, n_controls):
    """Sample controls from the cohort"""
    n_controls = min(n_controls, cohort.shape[0])
    if n_controls < cohort.shape[0]:
        controls = cohort.sample(n=n_controls).reset_index(drop=True)
    else:
        controls = cohort
    return controls


def get_cases(first_events, endpoint, n_cases=250_000):
    """Get cases dataset"""
    cols = ["finregistryid", "birth_year", "death_year", "female", "age"]
    cases = first_events.loc[first_events["endpoint"] == endpoint, cols]
    cases = cases.reset_index(drop=True)
    if n_cases < cases.shape[0]:
        cases = cases.sample(n_cases).reset_index(drop=True)
    cases["start"] = np.maximum(cases["birth_year"], FOLLOWUP_START)
    cases["stop"] = cases["birth_year"] + cases["age"]
    cases["outcome"] = 1
    cases = cases.drop(columns=["age"])
    return cases


def get_exposed(first_events, exposure, cases):
    """Get exposed subjects. Exposures after outcome are excluded."""
    cols = ["finregistryid", "birth_year", "age"]
    exposed = first_events.loc[first_events["endpoint"] == exposure, cols]

    exposed = exposed.rename({"age": "exposure_age"})
    outcome_age = cases[["finregistryid", "age"]].rename({"age": "outcome_age"})
    exposed = exposed.merge(outcome_age, how="left", on="finregistryid")
    exposed = exposed.loc[exposed["age"] > exposed["exposure_age"]]

    exposed["duration"] = exposed["birth_year"] + exposed["age"]
    exposed["exposure"] = 1
    exposed = exposed[["finregistryid", "duration", "exposure"]]

    return exposed


def calculate_case_cohort_weights(
    caseids, controlids, sample_of_caseids, sample_of_controlids
):
    """
    Calculate case-cohort weights for cases and controls.

    Args:
        caseids (list): finregistryids for cases
        controlids (list): finregistryids for controls
        sample_of_caseids (list): finregistryids for cases included in the sample
        sample_of_controlids (list): finregistryids for controls included in the sample

    Returns: 
        weight_cases (float): case-cohort weight for cases
        weight_controls (float): case-cohort weight for controls

    Raises: 
        ZeroDivisionError: if there are no non-cases among controls
    """
    non_cases = set(controlids) - set(caseids)
    non_cases_in_sample = set(sample_of_controlids) - set(sample_of_caseids)

    try:
        weight_cases = 1 / (len(sample_of_caseids) / len(caseids))
        weight_controls = 1 / (len(non_cases_in_sample) / len(non_cases))
    except ZeroDivisionError as err:
        logger.warning(f"{err}: No non-cases among controls")
        weight_cases = np.nan
        weight_controls = np.nan

    return (weight_cases, weight_controls)
