"""Functions for sampling the data"""

import numpy as np
from risteys_pipeline.log import logger

CONTROLS_PER_CASE = 2
MIN_CONTROLS = 500


def sample_controls(cohort, n_controls, sex=None):
    """
    Sample controls from the cohort
    
    Args: 
        cohort (DataFrame): cohort dataset, output of get_cohort()
        n_controls (num): number of controls to sample
        sex (str, default None): should controls be sampled of a specific sex 

    Returns:
        controls (DataFrame): controls sampled from the cohort
    """

    if sex is None:
        cohort_ = cohort
    elif sex == "female":
        cohort_ = cohort.loc[cohort["female"] == 1]
    elif sex == "male":
        cohort_ = cohort.loc[cohort["female"] == 0]
    else:
        raise ValueError("sex not 'both', 'female' or 'male'")

    if n_controls < cohort_.shape[0]:
        controls = cohort_.sample(n=n_controls)
    else:
        controls = cohort_

    logger.debug(f"{controls.shape[0]} controls sampled")

    return controls


def sample_cases(cases, n_cases):
    """
    Sample cases from all_cases

    Args:
        cases (DataFrame): cases dataset (persons with endpoint)
        n_cases (int): number of cases to sample

    Returns:
        cases_sample (DataFrame): sample of cases
    """

    if n_cases < cases.shape[0]:
        cases_sample = cases.sample(n=n_cases)
    else:
        cases_sample = cases

    logger.debug(f"{cases_sample.shape[0]} cases sampled")

    return cases_sample


def get_sampling_counts(cases, cohort, exposed=None, limit=10_000):
    """
    Get the number of cases and controls.

    The method is adapted from Groenwold & van Smeden (2017):
    https://journals.lww.com/epidem/Abstract/2017/11000/Efficient_Sampling_in_Unmatched_Case_Control.11.aspx

    The upper limit of cases + controls is fixed due to computational constraints.

    p1: exposure prevalence in cases
    p0: exposure prevalence in cohort
    R: optimal proportion of cases among all subjects

    Args:
        cases (DataFrame): dataset with all cases (persons with outcome)
        cohort (DataFrame): dataset with all cohort members
        exposed (DataFrame): dataset with all exposed persons (persons with exposure)
        limit (int): upper limit for cases + controls
    """

    if exposed is not None:

        exposed_cases = exposed.merge(cases, how="inner").shape[0]
        exposed_cohort = exposed.merge(cohort, how="inner").shape[0]

        p1 = exposed_cases / cases.shape[0]
        p0 = exposed_cohort / cohort.shape[0]

        q1 = 1 - p1
        q0 = 1 - p0

        R = (-1 * p0 * q0 + np.sqrt(p1 * q1 * p0 * q0)) / (p1 * q1 - p0 * q0)

        n_cases = np.minimum(R * limit, cases.shape[0])
        n_controls = (1 - R) / R * n_cases

        logger.debug(f"Sampling ratio: 1:{(1-R)/R:.2f}")

    else:

        n_cases = min(cases.shape[0], limit / (CONTROLS_PER_CASE + 1))
        n_controls = max(n_cases * CONTROLS_PER_CASE, MIN_CONTROLS)

    n_cases = round(n_cases)
    n_controls = round(n_controls)

    return n_cases, n_controls


def calculate_case_cohort_weights(
    caseids, controlids, sample_of_caseids, sample_of_controlids
):
    """
    Calculate case-cohort weights for cases and controls.

    Args:
        caseids (list): person IDs for cases
        controlids (list): person IDs for controls
        sample_of_caseids (list): person IDs for cases included in the sample
        sample_of_controlids (list): person IDs for controls included in the sample

    Returns: 
        weight_cases (float): case-cohort weight for cases
        weight_controls (float): case-cohort weight for controls

    Raises: 
        ZeroDivisionError: if there are no non-cases among controls
    """
    non_cases = len(controlids) - len(caseids)
    non_cases_in_sample = len(set(sample_of_controlids.values) - set(caseids.values))

    try:
        weight_cases = 1 / (len(sample_of_caseids.values) / len(caseids.values))
        weight_controls = 1 / (non_cases_in_sample / non_cases)
    except ZeroDivisionError as err:
        logger.warning(f"{err}: No non-cases among controls")
        weight_cases = np.nan
        weight_controls = np.nan

    return (weight_cases, weight_controls)
