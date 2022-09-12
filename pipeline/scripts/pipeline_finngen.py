from sys import stderr

import pandas as pd

from risteys_pipeline import config
from risteys_pipeline.finngen.load_data import load_data
from risteys_pipeline.finregistry.cumulative_incidence import cumulative_incidence_function
from risteys_pipeline.finregistry.distributions import compute_distribution
from risteys_pipeline.finregistry.key_figures import compute_key_figures
from risteys_pipeline.finregistry.survival_analysis import (
    get_cases,
    get_cohort
)
from risteys_pipeline.finregistry.write_data import get_output_filepath
from risteys_pipeline.log import logger


def pipeline():
    # --- 0. Check input and output paths
    print_config_paths(config)
    check_paths(config)

    # --- 1. Densify first-events
    # TODO

    # --- 2. Load data
    df_definitions, df_minimal_phenotype, df_first_events = load_data(
        config.FINNGEN_ENDPOINT_DEFINITIONS,
        config.FINNGEN_MINIMAL_PHENOTYPE,
        config.FINNGEN_COVARIATES,
        config.FINNGEN_DENSIFIED_FIRST_EVENTS,
        config.FINNGEN_DETAILED_LONGITUDINAL
    )

    # --- 3. Pipeline
    # Run key figures
    kf_all = compute_key_figures(df_first_events, df_minimal_phenotype, index_persons=False)

    kf_all.to_csv(get_output_filepath(
        "key_figures_all",
        "csv",
        config.FINNGEN_OUTPUT_DIRECTORY
    ), index=False)

    # Run age and year distributions
    dist_age = compute_distribution(df_first_events, "age")
    dist_year = compute_distribution(df_first_events, "year")

    dist_age.to_csv(get_output_filepath(
        "distribution_age",
        "csv",
        config.FINNGEN_OUTPUT_DIRECTORY
    ), index=False)
    dist_year.to_csv(get_output_filepath(
        "distribution_year",
        "csv",
        config.FINNGEN_OUTPUT_DIRECTORY
    ), index=False)

    # Run cumulative incidence and write to a file
    logger.info("Running cumulative incidence on core endpoints")
    ci_endpoints = df_definitions.loc[df_definitions.is_core, "endpoint"]
    cohort = get_cohort(df_minimal_phenotype)
    for endpoint in ci_endpoints:
        cases = get_cases(endpoint, df_first_events, cohort)
        cif = cumulative_incidence_function(endpoint, cases, cohort)

        if isinstance(cif, pd.DataFrame):  # if there were enough cases to compute the CIF
            cif.to_csv(get_output_filepath(
                f"cumulative_incidence__{endpoint}",
                "csv",
                config.FINNGEN_OUTPUT_DIRECTORY
            ), index=False)
        else:
            logger.warning(f"Could not run cumulative incidence on {endpoint}")


def check_paths(config):
    """Validate input and output paths taken from the configuration file"""
    logger.info("Checking input and output paths")
    # Path.is_file() is used to check that the path exists and it is a file
    assert config.FINNGEN_ENDPOINT_DEFINITIONS.is_file()
    assert config.FINNGEN_MINIMAL_PHENOTYPE.is_file()
    assert config.FINNGEN_COVARIATES.is_file()
    assert config.FINNGEN_DENSIFIED_FIRST_EVENTS.is_file()
    assert config.FINNGEN_DETAILED_LONGITUDINAL.is_file()

    # Similarly with Path.is_dir(): checking path existence and type is directory
    assert config.FINNGEN_OUTPUT_DIRECTORY.is_dir()


def print_config_paths(config):
    """Print out the configuration for input and output files.

    Useful when looking at the logs of previous run to check what files were used.
    """
    message = ""

    inputs = {
        "endpoint definitions": config.FINNGEN_ENDPOINT_DEFINITIONS,
        "minimal phenotype": config.FINNGEN_MINIMAL_PHENOTYPE,
        "analysis covariates": config.FINNGEN_COVARIATES,
        "densified endpoint first-events": config.FINNGEN_DENSIFIED_FIRST_EVENTS,
        "detailed longitudinal": config.FINNGEN_DETAILED_LONGITUDINAL
    }
    message += "INPUTS\n"
    for desc, path in inputs.items():
        message += f"\t{desc}:\n\t\t{path}\n"

    message += "OUTPUT\n"
    message += f"\toutput directory:\n\t\t{config.FINNGEN_OUTPUT_DIRECTORY}"

    print(message, file=stderr)


if __name__ == '__main__':
    pipeline()
