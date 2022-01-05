"""Functions for sampling the data"""

import numpy as np
import pandas as pd
from random import sample
from risteys_pipeline.log import logger
from risteys_pipeline.config import FOLLOWUP_START, FOLLOWUP_END


def sample_cases_and_controls(df, n_cases=250000, controls_per_case=2):
    """Samples df and adds case-cohort weights (`weight`) and indicators for cases/controls (`case`).
    
    Args:
        df (DataFrame): dataframe with the following columns: outcome_year, finregistryid
        n_cases (int, optional): maximum number of cases to include
        controls_per_case (int, optional): number of controls to include per case

    Returns: 
        df_sample (DataFrame): sampled dataframe
    """

    caseids = df.loc[
        df["outcome_year"].between(FOLLOWUP_START, FOLLOWUP_END), "finregistryid"
    ].tolist()
    controlids = df["finregistryid"].tolist()

    if n_cases > len(caseids):
        logger.info(f"Requested {n_cases} cases but found {len(caseids)}")
        n_cases = len(caseids)

    n_controls = round(n_cases * controls_per_case)

    if n_controls > len(controlids):
        logger.info(f"Requested {n_controls} controls but found {len(controlids)}")
        n_controls = len(controlids)

    sample_of_caseids = sample(caseids, n_cases)
    sample_of_controlids = sample(controlids, n_controls)

    weight_cases, weight_controls = calculate_case_cohort_weights(
        caseids, controlids, sample_of_caseids, sample_of_controlids
    )

    df_sample_cases = df.loc[df["finregistryid"].isin(sample_of_caseids)].copy()
    df_sample_cases = df_sample_cases.reset_index(drop=True)
    df_sample_cases["case"] = 1
    df_sample_cases["weight"] = weight_cases

    df_sample_controls = df.loc[df["finregistryid"].isin(sample_of_controlids)].copy()
    df_sample_controls = df_sample_controls.reset_index(drop=True)
    df_sample_controls["case"] = 0
    df_sample_controls["weight"] = weight_controls

    df_sample = pd.concat([df_sample_cases, df_sample_controls], axis=0)
    df_sample = df_sample.reset_index(drop=True)

    return df_sample


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
