"""FinRegistry pipeline"""

from risteys_pipeline.config import FINREGISTRY_OUTPUT_DIR
from risteys_pipeline.finregistry.load_data import (
    load_endpoints_data,
    load_minimal_phenotype_data,
    load_first_events_data,
)
from risteys_pipeline.finregistry.key_figures import compute_key_figures
from risteys_pipeline.finregistry.distributions import compute_distribution
from risteys_pipeline.finregistry.cumulative_incidence import cumulative_incidence
from risteys_pipeline.finregistry.survival_analysis import get_cohort, prep_all_cases
from risteys_pipeline.finregistry.write_data import (
    get_output_filepath,
    summary_stats_to_json,
    write_json_to_file,
)


def pipeline():
    """Running the Risteys pipeline on FinRegistry data"""

    # Read data
    endpoints = load_endpoints_data()
    minimal_phenotype = load_minimal_phenotype_data()
    first_events = load_first_events_data(endpoints, minimal_phenotype)

    # Prepare cohort and all cases
    cohort = get_cohort(minimal_phenotype)
    all_cases = prep_all_cases(first_events, cohort)

    # Run key figures
    kf_all = compute_key_figures(first_events, minimal_phenotype, index_persons=False)
    kf_index_persons = compute_key_figures(
        first_events, minimal_phenotype, index_persons=True
    )

    # Run age and year distributions
    dist_age = compute_distribution(first_events, "age")
    dist_year = compute_distribution(first_events, "year")

    # Write key figures and distributions to file
    summary_stats_json = summary_stats_to_json(kf_all, dist_age, dist_year)
    kf_json = kf_index_persons.set_index("endpoint").to_json(orient="index")
    write_json_to_file(
        summary_stats_json,
        get_output_filepath("summary_stats", "json", FINREGISTRY_OUTPUT_DIR),
    )
    write_json_to_file(
        kf_json,
        get_output_filepath("key_figures_index", "json", FINREGISTRY_OUTPUT_DIR),
    )

    # Run cumulative incidence and write to a file
    ci = cumulative_incidence(cohort, all_cases, endpoints)
    ci.to_csv(FINREGISTRY_OUTPUT_DIR / "cumulative_incidence.csv", index=False)


if __name__ == "__main__":
    pipeline()

