import numpy as np
import pandas as pd
from risteys_pipeline.sample import calculate_case_cohort_weights


def test_calculate_case_cohort_weights_cases():
    """Test case-cohort weight for cases"""
    cases = pd.Index([1, 2, 3, 4])
    controls = pd.Index([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    sample_of_cases = pd.Index([1, 2])
    sample_of_controls = pd.Index([2, 5, 7, 8])
    weight_cases, _ = calculate_case_cohort_weights(
        cases, controls, sample_of_cases, sample_of_controls
    )
    expected = 1 / (2 / 4)
    assert weight_cases == expected


def test_calculate_case_cohort_weights_controls():
    """Test case-cohort weight for controls"""
    cases = pd.Index([1, 2, 3, 4])
    controls = pd.Index([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    sample_of_cases = pd.Index([1, 2])
    sample_of_controls = pd.Index([2, 5, 7, 8])
    _, weight_controls = calculate_case_cohort_weights(
        cases, controls, sample_of_cases, sample_of_controls
    )
    expected = 1 / (3 / 6)
    assert weight_controls == expected


def test_calculate_case_cohort_weights_no_noncases():
    """Test case-cohort weights if there is no non-cases"""
    cases = pd.Index([1, 2, 3, 4, 5])
    controls = pd.Index([1, 2, 3, 4, 5])
    sample_of_cases = pd.Index([1, 2])
    sample_of_controls = pd.Index([2, 3, 4, 5])
    weight_cases, _ = calculate_case_cohort_weights(
        cases, controls, sample_of_cases, sample_of_controls
    )
    assert np.isnan(weight_cases)

