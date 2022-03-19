"""Functions for sampling the data"""

import numpy as np
from risteys_pipeline.log import logger
from risteys_pipeline.config import FOLLOWUP_START


def sample_controls(cohort, n_controls):
    """
    Sample controls from the cohort
    
    Args: 
        cohort (DataFrame): cohort dataset, output of get_cohort()
        n_controls (num): number of controls to sample

    Returns:
        controls (DataFrame): controls sampled from the cohort
    """
    if n_controls < cohort.shape[0]:
        controls = cohort.sample(n=n_controls).reset_index(drop=True)
    else:
        controls = cohort
    logger.info(f"{controls.shape[0]} controls sampled")
    return controls


def sample_cases(all_cases, endpoint, n_cases=250_000):
    """
    Sample cases from all_cases

    Args:
        all_cases (DataFrame): dataset with cases for all endpoints
        endpoint (str): name of the endpoint
        n_cases (int): number of cases to sample

    Returns:
        cases (DataFrame): dataset with all cases with `endpoint`
        caseids_total (int): FinRegistry IDs for all cases with `endpoint`
    """
    cols = ["finregistryid", "birth_year", "death_year", "female", "age"]
    cases = all_cases.loc[all_cases["endpoint"] == endpoint, cols]
    cases = cases.reset_index(drop=True)

    caseids_total = cases["finregistryid"]
    if n_cases < len(caseids_total):
        cases = cases.sample(n_cases).reset_index(drop=True)
    
    cases["start"] = np.maximum(cases["birth_year"], FOLLOWUP_START)
    cases["stop"] = cases["birth_year"] + cases["age"]
    cases["outcome"] = 1
    cases = cases.drop(columns=["age"])
    logger.info(f"{cases.shape[0]} cases sampled")
    
    return (cases, caseids_total)


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
