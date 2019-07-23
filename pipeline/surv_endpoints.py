"""
Select pairs of endpoints to do survival analysis on.

Usage
-----
    python surv_endpoints.py <path-to-data-dir>

Input files
-----------
- input.hdf5
  Each row is an event with FinnGen ID, Endpoint and time information.
- demo_endpoints.tsv
  List of #DEMO endpoints, one endpoint per line

Description
-----------
Survival analysis will be done on many pairs of endpoints.

If a user wants to know the strongest associations for endpoint E,
then we have to do a Cox regression for each endpoint pair that
contains E. That is:
- (*, E): association from any endpoint that then leads to endpoint E
- (E, *): association from E that then leads to any endpoint.

This is a lot endpoint combinations.

We filter the possible endpoint combinations:
- by only selecting endpoints that have enough individuals in order to
  have enough statistical power
- by selecting only #DEMO endpoints as endpoints of interest (so every
  pair containing any endpoint and 1 endpoint of interest)
"""

from pathlib import Path
from sys import argv

import numpy as np
import pandas as pd

from log import logger


# Files
DATA_DIR = Path(argv[1])
INPUT_EVENTS = "input.hdf5"
INPUT_DEMO_ENDPOINTS = "demo_endpoints.tsv"
OUTPUT_NAME = "filtered_pairs.csv"

# Filter parameters
CROSS_THRESHOLD = 5  # how many individuals to have, at least, in each
                     # cell of the frequency table
LATER_THRESHOLD = 25 # how many individuals to have, at least, for the
                     # "later" endpoints


def prechecks(events_path, demo_endpoints_path, output_path):
    """Perform checks before running to fail earlier rather than later"""
    logger.info("Performing pre-checks")
    assert events_path.exists(), f"{events_path} doesn't exist"
    assert demo_endpoints_path.exists(), f"{demo_endpoints_path} doesn't exist"
    assert not output_path.exists(), f"{output_path} already exists, not overwriting it"

    # Check event file headers
    df = pd.read_hdf(events_path, stop=0)
    cols = set(df.columns)
    expected_cols = set(["FINNGENID", "EVENT_AGE", "EVENT_YEAR", "ENDPOINT"])
    assert expected_cols.issubset(cols), f"wrong columns in input file: {expected_cols} not in {cols}"


def main(events_path, demo_endpoints_path, output_path):
    """Get a selection of pairs of endpoints to do survival analysis on"""
    prechecks(events_path, demo_endpoints_path, output_path)

    (df, demo_endpoints) = load_data(events_path, demo_endpoints_path)
    matrix = build_matrix(df)
    pairs = build_pairs(matrix, demo_endpoints)
    pairs = filter_prior_later(pairs, matrix)
    pairs = filter_crosstab(pairs, matrix)
    write_output(pairs, output_path)


def load_data(events_path, demo_endpoints_path):
    """Load input data"""
    logger.info("Loading data")
    # Get the list of #DEMO endpoints
    demo = pd.read_csv(demo_endpoints_path).values.flatten()

    # Read the longitudinal file
    df = pd.read_hdf(events_path)

    # Keep only events after 1998, when we have registry data
    df = df[df.EVENT_YEAR.gt(1997)]

    return (df, demo)


def build_matrix(df):
    """Build matrix of 'individual' × 'endpoint first event' """
    logger.info("Building matrix of individual × endpoint")

    matrix = (
        df.groupby(["FINNGENID", "ENDPOINT"], sort=False)
        ["EVENT_AGE"]
        .min()
        .unstack(level="ENDPOINT")
    )

    return matrix


def build_pairs(matrix, demo_endpoints):
    """Build a list of pairs of endpoints, with #DEMO endpoints as endpoints of interest"""
    logger.info("Building full list of pairs")
    endpoint_counts = matrix.count()  # count n. individuals by endpoints
    prior_endpoints = endpoint_counts[endpoint_counts >= CROSS_THRESHOLD].index
    later_endpoints = endpoint_counts[
        (endpoint_counts >= LATER_THRESHOLD)
        & (endpoint_counts.index.isin(demo_endpoints))
    ].index

    # Build all possible pairs of endpoints, filter them out after
    pairs = []
    for prior in prior_endpoints:
        for later in later_endpoints:
            if prior != later:
                pairs.append((prior, later))
                pairs.append((later, prior))

    return pairs


def filter_prior_later(pairs, matrix):
    """Filter pairs by checking the number of individuals having the prior->later pair"""
    logger.info("Filtering pairs by number prior->later")
    npairs = len(pairs)

    filtered_pairs = []
    for idx_pair, pair in enumerate(pairs):
        (prior, later) = pair

        (nindivs, _cols) = matrix[matrix[prior] < matrix[later]].shape
        if nindivs >= CROSS_THRESHOLD:
            filtered_pairs.append(pair)
        else:
            logger.debug(f"{nindivs} < {CROSS_THRESHOLD} for pair {pair}")

        print(f"done pair {idx_pair + 1}/{npairs} : {(idx_pair + 1) / npairs * 100:.2f}%", end="\r")
    print()  # keep the last "done pair …" message

    return filtered_pairs


def filter_crosstab(filtered_pairs, matrix):
    """Filter pairs by checking the number of individuals in each cell of the cross table"""
    logger.info("Filtering pairs by number in cross table")
    npairs = len(filtered_pairs)
    res_pairs = []
    for idx_pair, pair in enumerate(filtered_pairs):
        (prior, later) = pair

        s_prior = (
            (matrix[prior] < matrix[later])
            | (matrix[prior].notna() & matrix[later].isna())
        )
        s_later = matrix[later].notna()

        # Frequency table
        ftable = pd.crosstab(s_prior, s_later)
        if np.all(ftable >= CROSS_THRESHOLD):
            res_pairs.append(pair)
        else:
            logger.debug(f"Rejected pair {pair}, cross-table: {ftable}")

        print(f"done pair {idx_pair + 1}/{npairs} : {(idx_pair + 1) / npairs * 100:.2f}%", end="\r")
    print()  # keep the last "done pair …" message

    return res_pairs


def write_output(pairs, output_path):
    """Write out selected endpoint pairs as a CSV file"""
    logger.info("Writing output file")
    pd.DataFrame(
        pairs,
        columns=["prior", "later"]
    ).to_csv(
        output_path,
        index=False
    )


if __name__ == '__main__':
    main(
        DATA_DIR / INPUT_EVENTS,
        DATA_DIR / INPUT_DEMO_ENDPOINTS,
        DATA_DIR / OUTPUT_NAME,
    )
