import numpy as np
import pandas as pd
from risteys_pipeline.sample import calculate_sampling_weight


def test_calculate_sampling_weight():
    """Test case-cohort weight"""
    cases = [1, 2, 3, 4]
    sample_of_cases = [1, 2]
    weight = calculate_sampling_weight(sample_of_cases, cases)
    expected = 1 / (2 / 4)
    assert weight == expected


