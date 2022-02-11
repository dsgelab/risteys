"""Functions for sampling the data"""

import numpy as np
from risteys_pipeline.log import logger

def calculate_case_cohort_weights(
    caseids, controlids, sample_of_caseids, sample_of_controlids
):
    """Calculate case-cohort weights for cases and controls.

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
