"""
Reads the stats from a HDF5 file and output them to a JSON file so
they can be imported in a database afterwards.

Usage:
    python stats_to_json.py <path-to-data-dir>
"""
import json
from collections import defaultdict
from pathlib import Path
from sys import argv

import pandas as pd
import numpy as np

from log import logger


INPUT_FILENAME = "stats.hdf5"
OUTPUT_FILENAME = "stats.json"

LABELS_YEARS = [
    "≤1969",
    "1970—1974",
    "1975—1979",
    "1980—1984",
    "1985—1989",
    "1990—1994",
    "1995—1999",
    "2000—2004",
    "2005—2009",
    "2010—2014",
    "≥2015",
]
LABELS_AGES = [
    "0—9",
    "10—19",
    "20—29",
    "30—39",
    "40—49",
    "50—59",
    "60—69",
    "70—79",
    "80—89",
    "≥90",
]

def prechecks(input_path, output_path):
    """Perform early checks to fail earlier rather than later"""
    assert input_path.exists(), f"{input_path} already exists, not overwritting it"
    assert not output_path.exists(), f"{output_path} already exists, not overwritting it"


def main(input_path, output_path):
    """Put the stats of the HDF5 input into a JSON output.

    Convert pandas objects to JSON and then merge all this objects
    into a single JSON output.
    """
    prechecks(input_path, output_path)

    logger.info(f"Reading data from: {input_path}")
    agg_stats = (
        pd.read_hdf(input_path, "/stats")
        .to_json(orient="index")
    )

    distrib_age = pd.read_hdf(input_path, "/distrib/age")
    distrib_age = dict_distrib(distrib_age, LABELS_AGES)
    distrib_age = json.dumps(distrib_age)

    distrib_year = pd.read_hdf(input_path, "/distrib/year")
    distrib_year = dict_distrib(distrib_year, LABELS_YEARS)
    distrib_year = json.dumps(distrib_year)

    # Manually craft the JSON output given the 3 JSON strings we already have
    logger.info(f"Writing out data to JSON in file {output_path}")
    output = f'{{"stats": {agg_stats}, "distrib_age": {distrib_age}, "distrib_year": {distrib_year}}}'
    with open(OUTPUT_PATH, "x") as f:
        f.write(output)

    logger.info("Done")


def dict_distrib(distrib, new_labels):
    """Transform distributions from a DataFrame to a Python dict

    Arguments:
    - distrib: pd.DataFrame
      Contains the data that will be turned into a dict.
      Must have columns: 'all', 'female', 'male'. Must have
      multi-index with first level: ENDPOINT, second level:
      distribution labels (intervals)
    - new_labels: list
      New labels for the distribution

    Return:
    - dict
      {"endpoint1": {
        "all": [["label", value], ...]},
        "female": ...},
       "endpoint 2": ...}
    """
    res = defaultdict(dict)

    # Some JSON implementations don't support NaN, so this will use null
    distrib = distrib.replace({np.nan: None})

    for (endpoint, series) in distrib.groupby("ENDPOINT"):
        table = (
            series
            .droplevel("ENDPOINT")
            .sort_index()
        )
        res[endpoint]["all"] = double_list(table["all"], new_labels)
        res[endpoint]["female"] = double_list(table["female"], new_labels)
        res[endpoint]["male"] = double_list(table["male"], new_labels)
    return res


def double_list(series, new_labels):
    """Convert a series into a native Python double-list.

    Arguments:
    - series: pd.Series
      A series from which we will take the values and associate them
      with the given 'new_labels'. No checks are done to match the
      series index with the new_labels.
    - new_labels: list
      New labels for the distribution

    Return:
    - list of list, ex: [["10-20", 123], ["20-30", 12], …]
    """
    return [[idx, val] for idx, val in zip(new_labels, series)]


if __name__ == '__main__':
    DATA_DIR = Path(argv[1])
    INPUT_PATH = DATA_DIR / INPUT_FILENAME
    OUTPUT_PATH = DATA_DIR / OUTPUT_FILENAME
    main(INPUT_PATH, OUTPUT_PATH)
