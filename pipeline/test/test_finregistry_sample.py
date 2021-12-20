import numpy as np
import pandas as pd
from risteys_pipeline.config import FOLLOWUP_START
from risteys_pipeline.finregistry.sample import (
    calculate_case_cohort_weights,
    sample_cases_and_controls,
)


def test_sample_cases_and_controls_n_cases():
    """Test the number of cases when there's less cases in the data than requested"""
    df = pd.DataFrame(
        {
            "finregistryid": [1, 2, 3, 4, 5],
            "outcome_year": [
                FOLLOWUP_START + 1,
                FOLLOWUP_START + 1,
                np.nan,
                np.nan,
                np.nan,
            ],
            "case": [1, 1, 0, 0, 0],
        }
    )
    df_sample = sample_cases_and_controls(df, n_cases=3, controls_per_case=1)
    observed = df_sample.loc[df_sample["case"] == 1].shape[0]
    expected = 2
    assert observed == expected


def test_sample_cases_and_controls_n_controls():
    """Test the number of controls when there's less controls in the data than requested"""
    df = pd.DataFrame(
        {
            "finregistryid": [1, 2, 3, 4, 5],
            "outcome_year": [
                FOLLOWUP_START + 1,
                FOLLOWUP_START + 1,
                np.nan,
                np.nan,
                np.nan,
            ],
            "case": [1, 1, 0, 0, 0],
        }
    )
    df_sample = sample_cases_and_controls(df, n_cases=2, controls_per_case=10)
    observed = df_sample.loc[df_sample["case"] == 0].shape[0]
    expected = 5
    assert observed == expected


def test_calculate_case_cohort_weights_cases():
    """Test case-cohort weight for cases"""
    cases = [1, 2, 3, 4]
    controls = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    sample_of_cases = [1, 2]
    sample_of_controls = [2, 5, 7, 8]
    weight_cases, _ = calculate_case_cohort_weights(
        cases, controls, sample_of_cases, sample_of_controls
    )
    expected = 1 / 2 / 4
    assert weight_cases == expected


def test_calculate_case_cohort_weights_controls():
    """Test case-cohort weight for controls"""
    cases = [1, 2, 3, 4]
    controls = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    sample_of_cases = [1, 2]
    sample_of_controls = [2, 5, 7, 8]
    _, weight_controls = calculate_case_cohort_weights(
        cases, controls, sample_of_cases, sample_of_controls
    )
    expected = 1 / 3 / 6
    assert weight_controls == expected


def test_calculate_case_cohort_weights_no_noncases():
    """Test case-cohort weights if there is no non-cases"""
    cases = [1, 2, 3, 4, 5]
    controls = [1, 2, 3, 4, 5]
    sample_of_cases = [1, 2]
    sample_of_controls = [2, 3, 4, 5]
    weight_cases, _ = calculate_case_cohort_weights(
        cases, controls, sample_of_cases, sample_of_controls
    )
    assert np.isnan(weight_cases)

