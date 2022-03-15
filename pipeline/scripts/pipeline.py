"""FinRegistry pipeline"""

from risteys_pipeline.finregistry.load_data import (
    load_endpoints_data,
    load_minimal_phenotype_data,
    load_first_events_data,
)
from risteys_pipeline.finregistry.summary_stats import compute_distribution, compute_key_figures, cumulative_incidence
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
    kf_all = compute_key_figures(first_events, minimal_phenotype, index_persons=False)
    kf_all.to_csv(output_path + "/key_figures_all.csv", index=False)
    kf_index_persons = compute_key_figures(first_events, minimal_phenotype, index_persons=True)
    kf_index_persons.to_csv(output_path + "/key_figures_index_persons.csv", index=False)

    # Run age and year distributions and write to a file
    dist_age = compute_distribution(first_events, "age")
    dist_age.to_csv(output_path + "/distribution_age.csv", index=True)
    dist_year = compute_distribution(first_events, "year")
    dist_year.to_csv(output_path + "/distribution_year.csv", index=True)

    # Run cumulative incidence and write to a file
    ci = cumulative_incidence(cohort, all_cases, endpoints)
    ci.to_csv(output_path + "/cumulative_incidence.csv", index=False)

if __name__ == "__main__":
    pipeline()

