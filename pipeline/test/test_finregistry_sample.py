import pandas as pd
import numpy as np
from risteys_pipeline.finregistry.sample import sample_cases_and_controls


def test_sample_cases_and_controls_n_cases():
    """Test the number of cases when there's less cases in the data than requested"""
    d = {"finregistryid": [1, 2, 3, 4, 5], "outcome": [1, 1, 0, 0, 0]}
    df = pd.DataFrame(d)
    caseids, _, _, _ = sample_cases_and_controls(df, n_cases=3, controls_per_case=1)
    expected = 2
    assert len(caseids) == expected


def test_sample_cases_and_controls_n_controls():
    """Test the number of controls when there's less controls in the data than requested"""
    d = {"finregistryid": [1, 2, 3, 4, 5], "outcome": [1, 1, 0, 0, 0]}
    df = pd.DataFrame(d)
    _, controlids, _, _ = sample_cases_and_controls(df, n_cases=2, controls_per_case=10)
    expected = 5
    assert len(controlids) == expected


def test_sample_cases_and_controls_weight_cases():
    """Test case-cohort weight for cases"""
    d = {
        "finregistryid": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        "outcome": [1, 1, 1, 1, 0, 0, 0, 0, 0, 0],
    }
    df = pd.DataFrame(d)
    _, _, weight_cases, _ = sample_cases_and_controls(
        df, n_cases=2, controls_per_case=2
    )
    expected = 1 / 2 / 4
    assert weight_cases == expected


def test_sample_cases_and_controls_weight_controls():
    """
    Test case-cohort weight for controls.
    The number of cases among controls is random so we'll test for a range of values.
    """
    d = {
        "finregistryid": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        "outcome": [1, 1, 1, 1, 0, 0, 0, 0, 0, 0],
    }
    df = pd.DataFrame(d)
    _, _, _, weight_control = sample_cases_and_controls(
        df, n_cases=4, controls_per_case=2
    )
    expected = [1 / n_cases / 6 for n_cases in range(4, 8)]
    assert weight_control in expected
