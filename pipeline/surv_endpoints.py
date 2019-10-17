"""
Select pairs of endpoints to do survival analysis on.

Usage
-----
    python surv_endpoints.py <path-to-data-dir>

Input files
-----------
- input.hdf5  /first_event
  Each row is the first-event of an endpoint for an individual.

Description
-----------
Survival analysis will be done on many pairs of endpoints.

If a user wants to know the strongest associations for endpoint E,
then we have to do a Cox regression for each endpoint pair that
contains E. That is:
- (*, E): association from any endpoint that then leads to endpoint E
- (E, *): association from E that then leads to any endpoint.

This is a lot of endpoint combinations.

We filter the possible endpoint combinations by only selecting
endpoints that have enough individuals in order to have enough
statistical power.
"""

from pathlib import Path
from sys import argv

import numpy as np
import pandas as pd

from log import logger


# Files
DATA_DIR = Path(argv[1])
INPUT_EVENTS = "input.hdf5"
OUTPUT_NAME = "filtered_pairs.csv"

# Parameters
CROSS_THRESHOLD = 5  # how many individuals to have, at least, in each
                     # cell of the frequency table
LATER_THRESHOLD = 25 # how many individuals to have, at least, for the
                     # "later" endpoints
STUDY_STARTS_AFTER = 1997  # Look at the data after this year
STUDY_ENDS_BEFORE  = 2018  # Look at the data before this year


def prechecks(events_path, output_path):
    """Perform checks before running to fail earlier rather than later"""
    logger.info("Performing pre-checks")
    assert events_path.exists(), f"{events_path} doesn't exist"
    assert not output_path.exists(), f"{output_path} already exists, not overwriting it"

    # Check event file headers
    df = pd.read_hdf(events_path, "/first_event", stop=0)
    cols = set(df.columns)
    expected_cols = set(["FINNGENID", "AGE", "YEAR", "ENDPOINT"])
    assert expected_cols.issubset(cols), f"wrong columns in input file: {expected_cols} not in {cols}"


def main(events_path, output_path):
    """Get a selection of pairs of endpoints to do survival analysis on"""
    prechecks(events_path, output_path)

    df = load_data(events_path)
    matrix = build_matrix(df)
    pairs = build_pairs(matrix)
    pairs = filter_prior_later(pairs, matrix)
    pairs = filter_crosstab(pairs, matrix)
    write_output(pairs, output_path)


def load_data(events_path):
    """Load input data"""
    logger.info("Loading data")
    # Read the longitudinal file
    df = pd.read_hdf(events_path, "/first_event")

    # Keep only events in [1998, 2018[, the period we have all
    # registry data.
    df = df[df.YEAR.gt(STUDY_STARTS_AFTER) & df.YEAR.lt(STUDY_ENDS_BEFORE)]

    return df


def build_matrix(df):
    """Build matrix of 'individual' × 'endpoint first event' """
    logger.info("Building matrix of individual × endpoint")

    matrix = (
        df.groupby(["FINNGENID", "ENDPOINT"], sort=False)
        ["AGE"]
        .min()
        .unstack(level="ENDPOINT")
    )

    return matrix


def build_pairs(matrix):
    """Build a list of pairs of endpoints"""
    logger.info("Building full list of pairs")

    # Pre-filter by selecting endpoints with enough individuals,
    # without looking at endpoint association.
    endpoint_counts = matrix.count()  # count n. individuals by endpoints
    prior_endpoints = endpoint_counts[endpoint_counts >= CROSS_THRESHOLD].index
    later_endpoints = endpoint_counts[endpoint_counts >= LATER_THRESHOLD].index

    # Build all possible pairs of endpoints, filter them out in a later stage
    pairs = []
    for prior in prior_endpoints:
        for later in later_endpoints:
            if prior != later:
                pairs.append((prior, later))

    # Making sure there is no duplicates
    df = pd.DataFrame(pairs, columns=["prior", "later"])
    size_orig, _ = df.shape
    size_dedup, _ = df.drop_duplicates(keep=False).shape
    assert size_orig == size_dedup, f"Duplicates in the list of pairs ({size_orig} != {size_dedup} pairs)"

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

        if (idx_pair + 1) % 1000 == 0:
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

        if (idx_pair + 1) % 1000 == 0:
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
        DATA_DIR / OUTPUT_NAME,
    )
