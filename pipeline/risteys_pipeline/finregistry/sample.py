"""Functions for sampling the data"""

import numpy as np
import pandas as pd
from random import sample
from risteys_pipeline.log import logger
from risteys_pipeline.config import FOLLOWUP_START, FOLLOWUP_END


def sample_cases_and_controls(df, n_cases=250000, controls_per_case=2):
    """Samples df and adds case-cohort weights and indicators for cases/controls"""

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


def calculate_case_cohort_weights(cases, controls, sample_of_cases, sample_of_controls):
    """Calculate case-cohort weights for cases and controls."""
    non_cases = set(controls) - set(cases)
    non_cases_in_sample = set(sample_of_controls) - set(sample_of_cases)

    try:
        weight_cases = 1 / len(sample_of_cases) / len(cases)
        weight_controls = 1 / len(non_cases_in_sample) / len(non_cases)
    except ZeroDivisionError as err:
        logger.warning(f"{err}: No non-cases among controls")
        weight_cases = np.nan
        weight_controls = np.nan

    return (weight_cases, weight_controls)
