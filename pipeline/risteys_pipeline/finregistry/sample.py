"""Functions for sampling the data"""

import numpy as np
from random import sample
from risteys_pipeline.log import logger


def sample_cases_and_controls(df, n_cases=250000, controls_per_case=2):
    """
    Create a sample of cases and controls and calculate case-cohort weights.
    
    Returns:
        - sample_of_cases (list): finregistryids for cases
        - sample_of_controls (list): finregistryids for controls 
        - weight_cases (float): case-cohort weight for cases
        - weight_controls (float): case-cohort weight for controls
    """
    cases = df.loc[df["outcome"] == 1, "finregistryid"].tolist()
    controls = df["finregistryid"].tolist()

    if n_cases > len(cases):
        logger.info(
            f"Less cases than requested: requested {n_cases}, found {len(cases)}"
        )

    n_controls = min(round(n_cases * controls_per_case), len(controls))
    n_cases = min(n_cases, len(cases))

    if n_cases * controls_per_case > len(controls):
        logger.info(
            f"Less controls than requested: requested {round(n_cases * controls_per_case)}, found {len(controls)}"
        )

    sample_of_cases = sample(cases, n_cases)
    sample_of_controls = sample(controls, n_controls)

    non_cases = set(controls) - set(cases)
    non_cases_in_sample = set(sample_of_controls) - set(sample_of_cases)

    try:
        weight_cases = 1 / len(sample_of_cases) / len(cases)
        weight_controls = 1 / len(non_cases_in_sample) / len(non_cases)
    except ZeroDivisionError:
        logger.warning("No non-cases among controls")
        weight_cases = np.nan
        weight_controls = np.nan

    return (sample_of_cases, sample_of_controls, weight_cases, weight_controls)

