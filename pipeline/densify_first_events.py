"""
Make a dense first-event file from the original sparse first-event file.

Usage
-----
  python densify_first_events.py <path-to-data-dir>

Input file
----------
- FINNGEN_PHENOTYPES.txt:
  Original first-event file with a matrix-like structure:
  - columns: endpoints, and additional columns for age and year at
    first-event and number of events for each endpoint
  - lines: one individual per line
  Source: FinnGen data

Output file
-----------
- dense_first_events.csv:
  - columns: individual ID, endpoint, age at first-event, year at first-event, number of events
  - lines: each line is the endpoint information for one individual

Description
-----------
The original first-event file has for a very sparse format, as most
the individuals have only a few endpoints amongst the ~ 15k columns.

Loading a file with 15k columns is quite slow with
pandas. Furthermore, it is not strictly necessary since only few
columns are relevant for each individuals.

To solve this, this script split the original first-event file on the
columns, then it creates a file with a dense format, where there is no
irrelevant information.
"""
from csv import excel_tab
from sys import argv
from pathlib import Path

import numpy as np
import pandas as pd

from log import logger


FIRST_EVENT_FILE = "FINNGEN_PHENOTYPES.txt"
OUTPUT_FILE = "dense_first_events.csv"

# Number of groups of columns
N_CHUNKS = 10


def prechecks(input_path, output_path):
    """Check existence of input and output files"""
    logger.info("Performing pre-checks")
    assert input_path.exists()
    assert not output_path.exists()


def main(input_path, output_path):
    """Write a dense fisrt-event file"""
    prechecks(input_path, output_path)

    # Get the headers
    df = pd.read_csv(input_path, dialect=excel_tab, nrows=0)
    headers = set(df.columns)
    endpoints = {
        e for e in headers
        if e + "_YEAR" in headers
        and e + "_AGE" in headers
        and e + "_NEVT" in headers
    }

    # Create the CSV output file
    output = open(output_path, "x")
    output.write("FINNGENID,ENDPOINT,AGE,YEAR,NEVT\n")

    # Get the data by group of endpoints
    chunks = np.array_split(list(endpoints), N_CHUNKS)
    for idx_chunk, chunk_endpoints in enumerate(chunks):
        logger.debug(f"Doing chunk {idx_chunk + 1}/{N_CHUNKS}")

        # Get the headers for this group of endpoints
        age_headers = [e + "_AGE" for e in chunk_endpoints]
        year_headers = [e + "_YEAR" for e in chunk_endpoints]
        nevt_headers = [e + "_NEVT" for e in chunk_endpoints]

        chunk_headers = list(chunk_endpoints)
        chunk_headers += age_headers
        chunk_headers += year_headers
        chunk_headers += nevt_headers
        chunk_headers.append("FINNGENID")

        # Read the input file with the current group of headers
        df = pd.read_csv(
            input_path,
            usecols=chunk_headers,
            dialect=excel_tab
        )
        # Set the correct header types
        types = {}
        types.update({h: np.float for h in age_headers})
        types.update({h: 'Int64' for h in year_headers})
        types.update({h: 'Int64' for h in nevt_headers})
        df = df.astype(types)

        # For each individual, write the endpoint values when they have the endpoint
        chunk_endpoints = set(chunk_headers).intersection(endpoints)
        for idx, series in df.iterrows():
            if idx % 10_000 == 0:
                logger.debug(f"individual {idx}/{df.shape[0]}")
            has_endpoints = series[chunk_endpoints] == 1
            # Keep only endpoints where has_endpoints is True
            has_endpoints = has_endpoints[has_endpoints]
            has_endpoints = list(has_endpoints.index)

            for endpoint in has_endpoints:
                finngenid = series.FINNGENID
                age = series[endpoint + "_AGE"]
                year = series[endpoint + "_YEAR"]
                nevt = series[endpoint + "_NEVT"]
                output.write(f"{finngenid},{endpoint},{age},{year},{nevt}\n")

    output.close()


if __name__ == '__main__':
    DATA_DIR = Path(argv[1])
    main(
        DATA_DIR / FIRST_EVENT_FILE,
        DATA_DIR / OUTPUT_FILE
    )
