"""
Takes the input CSV files and merge them into one HDF5 file.

Steps:
- filter out individuals according to PheWeb selected ones
- filter out endpoints that are too broad
- filter out endpoints that are comorbidities
- for each individual, sort their events by date
- merge events that are within a 30-day time window

Usage:
    python build_input_hdf.py <path-to-first-events> <path-to-info> <path-to-endpoint-defs> <path-to-samples> <output-output>

Input files:
- dense_first_events.csv
  Source: previous pipeline step
- FINNGEN_MINIMUM_DATA.txt
  Each row is an individual in FinnGen with some information.
  Source: FinnGen data
- Endpoint_definitions_FINNGEN_ENDPOINTS.tsv
  Each row is an endpoint definition.
  Source: FinnGen data
- COV_PHENO.txt
  Each row is an individual in FinnGen, with FinnGen ID. Only these
  individuals will be used for data processing in PheWeb.
  Source: FinnGen data
"""
from pathlib import Path
from sys import argv

import numpy as np
import pandas as pd

from log import logger


def main(first_event_path, info_path, samples_path, output_path):
    """Clean up and merge all the input files into one HDF5 file"""
    # Load data
    df_fevent = load_data(first_event_path, info_path)

    # Filter out the individuals
    df_fevent = filter_out_samples(df_fevent, samples_path)

    # Sort events for first-event data
    df_fevent = df_fevent.sort_values(by=["FINNGENID", "AGE"])
    df_fevent = df_fevent.reset_index(drop=True)
    
    # Write result to output
    logger.info(f"Writing merged and filtered input data to HDF5 file {output_path}")
    df_fevent.to_hdf(output_path, "/first_event")


def load_data(first_event_path, info_path):
    """Load the first-event data"""
    logger.info("Loading first-event data")

    # First-event file
    logger.debug("Loading the first-event dense data")
    df_fevent = pd.read_csv(first_event_path)

    df_fevent = df_fevent.astype({
        "FINNGENID": np.object,
        "ENDPOINT": np.object,
        "AGE": np.float64,
        "YEAR": np.int64,
        "NEVT": np.int64,
    })

    # Loading data file with ID -> SEX info
    logger.debug("Loading info data")
    dfsex = pd.read_csv(
        info_path,
        usecols=["FINNGENID", "SEX"]
    )
    dfsex = dfsex.astype({
        "FINNGENID": np.object,
        "SEX": "category",
    })

    # Perform one-hot encoding for SEX so it can be written to HDF
    # without the slow format="table".
    onehot = pd.get_dummies(dfsex["SEX"])
    dfsex = pd.concat([dfsex, onehot], axis=1)
    dfsex = dfsex.drop("SEX", axis=1)

    # Add SEX information to DataFrame
    # NOTE: for some individuals there is no sex information, so
    # "female" and "male" columns will be NaN and of type float64.
    logger.debug("Merging sex information into the DataFrames")
    df_fevent = df_fevent.merge(dfsex, on="FINNGENID", how="left")

    return df_fevent


def filter_out_samples(data, samples_path):
    """Filter out samples, select only the one included in PheWeb."""
    logger.info("Filtering out the samples.")
    (nbefore, _) = data.shape
    samples = pd.read_csv(samples_path, usecols=["FINNGENID"])
    data = data.merge(samples, on="FINNGENID")
    (nafter, _) = data.shape

    log_event_reduction(nbefore, nafter)
    return data


def log_event_reduction(nbefore, nafter):
    logger.debug(f"Data reduced from {nbefore} to {nafter} (𝚫 = {nbefore - nafter}, {(nbefore - nafter) / nbefore * 100:.1f} %)")


def sort_events(data):
    """Sort data by event date, grouping them by FinnGen ID"""
    logger.info("Sorting the events by FinnGenID > Endpoint > Event age")
    return data.sort_values(by=["FINNGENID", "ENDPOINT", "EVENT_AGE"])


def merge_events(df):
    """Merge events of same individual and endpoint if less than 30 days apart.

    NOTE: assumes rows are sorted by FINNGENID, ENDPOINT, EVENT_AGE
    will lead to wrong result otherwise.
    """
    logger.info("Merging events with 30-day time window")
    window = 30/365.25

    shifted = df.shift()
    shifted["end"] = shifted.EVENT_AGE + window

    # Compare only same individual & same endpoint, then check if time
    # difference between 2 successive events is less than the time
    # window.
    skip = (
        (df.FINNGENID == shifted.FINNGENID)
        & (df.ENDPOINT == shifted.ENDPOINT)
        & (df.EVENT_AGE <= shifted.end)
    )
    df_merged = df[~ skip]
    return df_merged


if __name__ == '__main__':
    INPUT_FIRST_EVENT = Path(argv[1])
    INPUT_INFO = Path(argv[2])
    INPUT_SAMPLES = Path(argv[3])
    OUTPUT_NAME = Path(argv[4])

    main(
        INPUT_FIRST_EVENT,
        INPUT_INFO,
        INPUT_SAMPLES,
        OUTPUT_NAME,
    )
