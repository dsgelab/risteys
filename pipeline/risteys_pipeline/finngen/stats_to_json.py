"""
Reads the stats from a HDF5 file and output them to a JSON file so
they can be imported in a database afterwards.

Usage:
    python stats_to_json.py <input-path> <output-path>
"""
import json
from collections import defaultdict
from pathlib import Path
from sys import argv

import pandas as pd
import numpy as np

from log import logger


def main(input_path, output_path):
    """Put the stats of the HDF5 input into a JSON output.

    Convert pandas objects to JSON and then merge all this objects
    into a single JSON output.
    """
    logger.info(f"Reading data from: {input_path}")
    agg_stats = (
        pd.read_hdf(input_path, "/stats")
        .to_json(orient="index")
    )

    distrib_age = pd.read_hdf(input_path, "/distrib/age")
    distrib_age = dict_distrib(distrib_age)
    distrib_age = json.dumps(distrib_age)

    distrib_year = pd.read_hdf(input_path, "/distrib/year")
    distrib_year = dict_distrib(distrib_year)
    distrib_year = json.dumps(distrib_year)

    # Manually craft the JSON output given the 3 JSON strings we already have
    logger.info(f"Writing out data to JSON in file {output_path}")
    output = f'{{"stats": {agg_stats}, "distrib_age": {distrib_age}, "distrib_year": {distrib_year}}}'
    with open(OUTPUT_PATH, "x") as f:
        f.write(output)

    logger.info("Done")


def dict_distrib(distrib):
    """Transform distributions from a DataFrame to a Python dict

    Arguments:
    - distrib: pd.DataFrame
      Contains the data that will be turned into a dict.
      Must have columns:
      . 'sex' with values in 'all', 'male', 'female'
      . 'interval_left'
      . 'interval_right'
      . 'count'

    Return:
    - dict
      {"endpoint1": {
        "all": [
          [
            # Note that 10.0 is in this interval, but values > 10.0
            # (e.g. 10.1) will be in the [10, 20] interval
            [0, 10],  # [left, right] interval.
            12
          ], [[10, 20], 101] ...]},
        "female": ...},
       "endpoint 2": ...}
    """
    res = defaultdict(dict)

    # Some JSON implementations don't support NaN, so this will use null.
    # Use null to mark unbounded intervals.
    distrib = distrib.replace({np.nan: None, np.NINF: None, np.PINF: None})

    for (endpoint, df) in distrib.groupby("endpoint"):
        endpoint_dist = {"all": [], "female": [], "male": []}

        # Sort bin by interval, putting left unbounded interval as the first bin
        df = df.sort_values("interval_left", na_position="first")

        for _, row in df.iterrows():
            bin = [
                [row.interval_left, row.interval_right],
                row["count"]  # can't use row.count because it references the count method
            ]
            endpoint_dist[row.sex].append(bin)

        res[endpoint] = endpoint_dist

    return res


if __name__ == '__main__':
    INPUT_PATH = Path(argv[1])
    OUTPUT_PATH = Path(argv[2])
    main(INPUT_PATH, OUTPUT_PATH)
