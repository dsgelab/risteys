"""Run analyses for FinRegistry data"""

import pandas as pd

from itertools import product

from risteys_pipeline.finregistry.load_data import (
    load_endpoints_data,
    load_minimal_phenotype_data,
    load_wide_first_events_data,
)
from risteys_pipeline.finregistry.preprocess_data import (
    list_excluded_subjects,
    preprocess_endpoints_data,
    preprocess_minimal_phenotype_data,
    preprocess_wide_first_events_data,
)
from risteys_pipeline.finregistry.sample import sample_cases_and_controls

# Load data
endpoints = load_endpoints_data()
minimal_phenotype = load_minimal_phenotype_data()

# Preprocess minimal phenotype and endpoint definitions data
excluded_subjects = list_excluded_subjects(minimal_phenotype)
endpoints = preprocess_endpoints_data(endpoints)
minimal_phenotype = preprocess_minimal_phenotype_data(
    minimal_phenotype, excluded_subjects
)

# Set up outcomes and exposures
outcomes = ["DEATH"]
exposures = ["T2D", "5_SCHZPHR"]

# Loop through outcomes and exposures

for outcome, exposure in product(outcomes, exposures):
    # Load first events data
    first_events = load_wide_first_events_data(exposure, outcome)
    first_events = preprocess_wide_first_events_data(first_events)

    # Merge minimal phenotype with first events
    # Only subjects in minimal phenotype are included
    df = minimal_phenotype.merge(first_events, how="left", on="finregistryid")

    # Sample cases and controls based on outcome
    caseids, controlids = sample_cases_and_controls(
        outcome, excluded_subjects, n_cases=250000, controls_per_case=2
    )
    df = df.loc[df["finregistryid"].isin(caseids + controlids), :].reset_index()

