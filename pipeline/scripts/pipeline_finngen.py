from argparse import ArgumentParser
from pathlib import Path
from sys import stderr

import pandas as pd

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
    args = parse_args()

    # --- 0. Check input and output paths
    print_config_paths(args)
    check_paths(args)

    # --- 1. Densify first-events
    # TODO

    # --- 2. Load data
    df_definitions, df_minimal_phenotype, df_first_events = load_data(
        args.input_endpoint_definitions,
        args.input_minimal_phenotype,
        args.input_covariates,
        args.input_densified_first_events,
        args.input_detailed_longitudinal
    )

    # --- 3. Pipeline
    # Run key figures
    kf_all = compute_key_figures(df_first_events, df_minimal_phenotype, index_persons=False)

    kf_all.to_csv(get_output_filepath(
        "key_figures_all",
        "csv",
        args.output_directory
    ), index=False)

    # Run age and year distributions
    dist_age = compute_distribution(df_first_events, "age")
    dist_year = compute_distribution(df_first_events, "year")

    dist_age.to_csv(get_output_filepath(
        "distribution_age",
        "csv",
        args.output_directory
    ), index=False)
    dist_year.to_csv(get_output_filepath(
        "distribution_year",
        "csv",
        args.output_directory
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
                args.output_directory
            ), index=False)
        else:
            logger.warning(f"Could not run cumulative incidence on {endpoint}")


def parse_args():
    parser = ArgumentParser()
    parser.add_argument(
        "-e", "--input-endpoint-definitions",
        help="definition file for endpoints (with and without control) and core status (TSV)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-m", "--input-minimal-phenotype",
        help="minimal phenotype file (TSV or gzipped-TSV)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-c", "--input-covariates",
        help="analysis covariates file (TSV or gzipped-TSV)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-f", "--input-densified-first-events",
        help="densified version of the endpoint first-events file (Feather)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-d", "--input-detailed-longitudinal",
        help="detailed longitudinal data file (TSV or gzipped-TSV)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-o", "--output-directory",
        help="pipeline output directory",
        required=True,
        type=Path
    )
    args = parser.parse_args()

    return args


def check_paths(args):
    logger.info("Checking input and output paths")
    # Path.is_file() is used to check that the path exists and it is a file
    assert args.input_endpoint_definitions.is_file()
    assert args.input_minimal_phenotype.is_file()
    assert args.input_covariates.is_file()
    assert args.input_densified_first_events.is_file()
    assert args.input_detailed_longitudinal.is_file()

    # Similarly with Path.is_dir(): checking path existence and type is directory
    assert args.output_directory.is_dir()


def print_config_paths(args):
    message = ""

    inputs = {
        "endpoint definitions": args.input_endpoint_definitions,
        "minimal phenotype": args.input_minimal_phenotype,
        "analysis covariates": args.input_covariates,
        "densified endpoint first-events": args.input_densified_first_events,
        "detailed longitudinal": args.input_detailed_longitudinal
    }
    message += "INPUTS\n"
    for desc, path in inputs.items():
        message += f"\t{desc}:\n\t\t{path}\n"

    message += "OUTPUT\n"
    message += f"\toutput directory:\n\t\t{args.output_directory}"

    print(message, file=stderr)


if __name__ == '__main__':
    pipeline()
