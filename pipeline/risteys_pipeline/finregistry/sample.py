"""Functions for sampling the data"""

from random import sample
from risteys_pipeline.finregistry.load_data import load_wide_first_events_data
from risteys_pipeline.finregistry.preprocess_data import (
    preprocess_wide_first_events_data,
)


def sample_cases_and_controls(df, n_cases=250000, controls_per_case=2):
    """
    Create a sample of cases and controls. Returns a tuple with two lists of finregistryids.
    """
    cases = df.loc[df["outcode"] == 1, "finregistryid"].tolist()
    controls = df["finregistryid"].tolist()

    n_controls = min(round(n_cases * controls_per_case), len(controls))
    n_cases = min(n_cases, len(cases))

    sample_of_cases = sample(cases, n_cases)
    sample_of_controls = sample(controls, n_controls)

    return (sample_of_cases, sample_of_controls)

