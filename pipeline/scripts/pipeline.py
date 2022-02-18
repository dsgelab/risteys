"""FinRegistry pipeline"""

from risteys_pipeline.finregistry.load_data import (
    load_endpoints_data,
    load_minimal_phenotype_data,
    load_first_events_data,
)
from risteys_pipeline.finregistry.summary_stats import compute_key_figures, cumulative_incidence
from risteys_pipeline.finregistry.sample import get_cohort
from risteys_pipeline.finregistry.survival_analysis import prep_all_cases

def pipeline():
    """Running the Risteys pipeline on FinRegistry data"""

    # Set up output path
    # TODO: move to config
    output_path = "~/risteys/results"

    # Read data
    endpoints = load_endpoints_data()
    minimal_phenotype = load_minimal_phenotype_data()
    first_events = load_first_events_data(endpoints, minimal_phenotype)

    # Prepare cohort and all cases
    cohort = get_cohort(minimal_phenotype)
    all_cases = prep_all_cases(first_events, cohort)

    # Run key figures and write to a file
    # TODO: run for index persons only
    kf = compute_key_figures(first_events, minimal_phenotype)
    kf.to_csv(output_path + "/key_figures.csv", index=False)

    # Run cumulative incidence and write to a file
    ci = cumulative_incidence(cohort, all_cases, endpoints)
    ci.to_csv(output_path + "/cumulative_incidence.csv", index=False)

if __name__ == "__main__":
    pipeline()

