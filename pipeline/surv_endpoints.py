"""
Select pairs of endpoints to do survival analysis on.

Usage
-----
    python surv_endpoints.py <path-to-data-dir>

Input files
-----------
- input.hdf5  /first_event
  Each row is the first-event of an endpoint for an individual.
  Source: previous pipeline step
- Endpoint_definitions_FINNGEN_ENDPOINTS.tsv
  Each row is an endpoint definition.
  Source: FinnGen data
- icd10cm_codes_2019.tsv
  Official ICD-10-CM file.
  Source: ftp://ftp.cdc.gov/pub/Health_Statistics/NCHS/Publications/ICD10CM/2019/
- ICD10_koodistopalvelu_2015-08_26_utf8.txt
  Finnish ICD code definitions.
  Source: Aki, then converted to utf8 with "iconv -f MAC -t UTF8"

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

from csv import excel_tab
from pathlib import Path
from sys import argv
import re

import numpy as np
import pandas as pd

from common import get_all_inclusions
from log import logger


# Files
DATA_DIR = Path(argv[1])
INPUT_EVENTS = "input.hdf5"
INPUT_ENDPOINTS = "Endpoint_definitions_FINNGEN_ENDPOINTS.tsv"
INPUT_ICD_CM = "icd10cm_codes_2019.tsv"
INPUT_ICD_FINN = "ICD10_koodistopalvelu_2015-08_26_utf8.txt"
OUTPUT_NAME = "filtered_pairs.csv"

# Where to look for ICD in the endpoint definitions file
ICD_COLS = [
    "OUTPAT_ICD",
    "HD_ICD_10",
    "COD_ICD_10",
    "KELA_REIMB_ICD"
]

# Parameters
CROSS_THRESHOLD = 5  # how many individuals to have, at least, in each
                     # cell of the frequency table
LATER_THRESHOLD = 25 # how many individuals to have, at least, for the
                     # "later" endpoints
STUDY_STARTS_AFTER = 1997  # Look at the data after this year
STUDY_ENDS_BEFORE  = 2018  # Look at the data before this year



def prechecks(events_path, endpoints_path, icd_cm_path, icd_finn_path, output_path):
    """Perform checks before running to fail earlier rather than later"""
    logger.info("Performing pre-checks")
    assert events_path.exists(), f"{events_path} doesn't exist"
    assert endpoints_path.exists(), f"{endpoints_path} doesn't exist"
    assert icd_cm_path.exists(), f"{icd_cm_path} doesn't exist"
    assert icd_finn_path.exists(), f"{icd_finn_path} doesn't exist"
    assert not output_path.exists(), f"{output_path} already exists, not overwriting it"

    # Check event file headers
    df = pd.read_hdf(events_path, "/first_event", stop=0)
    cols = set(df.columns)
    expected_cols = set(["FINNGENID", "AGE", "YEAR", "ENDPOINT"])
    assert expected_cols.issubset(cols), f"wrong columns in input file: {expected_cols} not in {cols}"


def main(events_path, endpoints_path, icd_cm_path, icd_finn_path, output_path):
    """Get a selection of pairs of endpoints to do survival analysis on"""
    prechecks(events_path, endpoints_path, icd_cm_path, icd_finn_path, output_path)

    # Load data
    df = load_data(events_path)
    endpoints = load_endpoints(endpoints_path)
    icds = load_icds(icd_cm_path, icd_finn_path)

    # Build list of pairs of endpoints
    matrix = build_matrix(df)
    pairs = build_pairs(matrix)

    # Filter pairs
    logger.info(f"len(pairs): {len(pairs)}")
    pairs = filter_overlapping_icds(pairs, endpoints, icds)
    logger.info(f"len(pairs): {len(pairs)}")
    pairs = filter_descendants(pairs, endpoints)
    logger.info(f"len(pairs): {len(pairs)}")
    pairs = filter_prior_later(pairs, matrix)
    logger.info(f"len(pairs): {len(pairs)}")
    pairs = filter_crosstab(pairs, matrix)
    logger.info(f"len(pairs): {len(pairs)}")

    # Write filtered pairs
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


def load_endpoints(endpoints_path):
    """Load the endpoint definitions"""
    df = pd.read_csv(
        endpoints_path,
        usecols=["NAME", "INCLUDE"] + ICD_COLS,
        skiprows=[1],  # comment line in the endpoints file
        dialect=excel_tab
    )
    return df


def load_icds(icd_cm, icd_finn):
    """Load the lists of ICD"""
    # ICD-10-CM
    cm = pd.read_csv(
        icd_cm,
        dialect=excel_tab,
        header=None,
        names=["code", "desc"],
        usecols=["code"]
    )
    cm = cm.code

    # Finnish version of ICDs
    finn = pd.read_csv(
        icd_finn,
        dialect=excel_tab,
        usecols=["A:Koodi1", "A:Koodi2"],
    )
    codes1 = finn.loc[finn["A:Koodi1"].notna(), "A:Koodi1"]
    codes2 = finn.loc[finn["A:Koodi2"].notna(), "A:Koodi2"]
    finn = set(codes1).union(set(codes2))

    # Remove the '.' in Finnish ICDs since the endpoint definitions don't have it
    finn = map(lambda s: s.replace(".", ""), finn)

    # Merge all ICD-10 codes
    icds = set(cm).union(finn)

    return icds


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


def filter_overlapping_icds(pairs, endpoints, icds):
    """Filter pairs if a pair has overlapping ICD codes"""
    logger.info("Filtering pairs by overlapping ICD-10s")
    res = []

    endpoint_icds = map_endpoint_icds(endpoints, icds)
    endpoint_parents = map_endpoint_parents(endpoints)

    for (prior, later) in pairs:
        # ICDs of prior endpoint
        icds_prior = endpoint_icds[prior]
        # ICDs of prior endpoint parents
        parents_prior = endpoint_parents.get(prior, [])
        for parent in parents_prior:
            icds = endpoint_icds[parent]
            icds_prior.update(icds)

        # ICDs of later endpoint
        icds_later = endpoint_icds[later]
        # ICDs of later endpoint parents
        parents_later = endpoint_parents.get(later, [])
        for parent in parents_later:
            icds = endpoint_icds[parent]
            icds_later.update(icds)

        if icds_prior.isdisjoint(icds_later):
            res.append((prior, later))

    return res


def map_endpoint_icds(definitions, icds):
    """Map each endpoint to its list of ICD-10s"""
    res = {}
    known = {}  # memoize regex expansions

    for _, row in definitions.loc[:, ["NAME"] + ICD_COLS].iterrows():
        endpoint_icds = []
        regexes = row.loc[ICD_COLS]
        regexes = regexes[regexes.notna()]
        regexes = map(lambda r: f"^({r})$", regexes.values)  # exact matches only
        regexes = set(regexes)  # remove duplicates

        for regex in regexes:
            if regex in known:
                endpoint_icds += known[regex]

            else:
                regex_icds = []
                for icd in icds:
                    match = re.match(regex, icd)
                    if match is not None:
                        endpoint_icds.append(icd)
                        regex_icds.append(icd)

                # Update regex -> ICDs memoization
                known[regex] = regex_icds

        res[row.NAME] = set(endpoint_icds)

    return res


def map_endpoint_parents(endpoints):
    """Map each endpoint to its direct parents"""
    res = {}

    for _, row in endpoints.iterrows():
        name = row.NAME
        if pd.notna(row.INCLUDE):
            children = row.INCLUDE.split("|")

            for child in children:
                existing = res.get(child, [])
                existing.append(name)
                res[child] = existing

    return res


def filter_descendants(pairs, endpoints):
    """Remove pairs where one endpoint includes the other"""
    logger.info("Filtering overlapping endpoint pairs")
    res = []

    inclusions = get_all_inclusions(endpoints)

    for (prior, later) in pairs:
        if later not in inclusions[prior] and prior not in inclusions[later]:
            res.append((prior, later))

    return res


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
        DATA_DIR / INPUT_ENDPOINTS,
        DATA_DIR / INPUT_ICD_CM,
        DATA_DIR / INPUT_ICD_FINN,
        DATA_DIR / OUTPUT_NAME,
    )
