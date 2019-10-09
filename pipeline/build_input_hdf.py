"""
Takes the input CSV files and merge them into one HDF5 file.

Steps:
- filter out individuals according to PheWeb selected ones
- filter out endpoints that are too broad
- filter out endpoints that are comorbidities
- for each individual, sort their events by date
- merge events that are within a 30-day time window

Usage:
    python build_input_hdf.py <path-to-data-dir>

Input files:
- dense_first_events.csv
  Source: previous pipeline step
- FINNGEN_ENDPOINTS_longitudinal_QCed.csv
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
from csv import excel_tab
from pathlib import Path
from sys import argv

import numpy as np
import pandas as pd

from log import logger

INPUT_FIRST_EVENT = "dense_first_events.csv"
INPUT_LONGIT = "FINNGEN_ENDPOINTS_longitudinal_QCed.csv"
INPUT_INFO = "FINNGEN_MINIMUM_DATA.txt"
INPUT_ENDPOINTS = "Endpoint_definitions_FINNGEN_ENDPOINTS.tsv"
INPUT_SAMPLES = "COV_PHENO.txt"
OUTPUT_NAME = "input.hdf5"


def prechecks(first_event_path, longit_path, info_path, endpoints_path, samples_path, output_path):
    """Perform checks before running to fail earlier rather than later"""
    logger.info("Performing pre-checks")
    assert first_event_path.exists()
    assert longit_path.exists()
    assert info_path.exists()
    assert endpoints_path.exists()
    assert samples_path.exists()
    assert not output_path.exists()

    # Check endpoint file headers
    df = pd.read_csv(endpoints_path, dialect=excel_tab, nrows=0)
    assert "NAME" in df.columns
    assert "OMIT" in df.columns
    assert "LEVEL" in df.columns
    assert "TAGS" in df.columns

    # Check samples file headers
    df = pd.read_csv(samples_path, dialect=excel_tab, nrows=0)
    assert "FINNGENID" in df.columns


def main(first_event_path, longit_path, info_path, endpoints_path, samples_path, output_path):
    """Clean up and merge all the input files into one HDF5 file"""
    prechecks(first_event_path, longit_path, info_path, endpoints_path, samples_path, output_path)

    # Load data
    df_fevent, df_longit = load_data(first_event_path, longit_path, info_path)

    # Filter out the individuals
    df_fevent = filter_out_samples(df_fevent, samples_path)
    df_longit = filter_out_samples(df_longit, samples_path)

    # Filter out the endpoints
    logger.info("Filtering out the endpoints for first-event and longitudinal data.")
    endpoints = get_filtered_endpoints(endpoints_path)
    # TODO maybe add the extras: BL_AGE, BL_YEAR, FU_END_AGE
    df_fevent = filter_out_endpoints(df_fevent, endpoints)
    df_longit = filter_out_endpoints(df_longit, endpoints)

    # Sort events for first-event data
    df_fevent = df_fevent.sort_values(by=["FINNGENID", "AGE"])
    df_fevent = df_fevent.reset_index(drop=True)
    
    # Event processing for longitudinal data
    df_longit = sort_events(df_longit)
    df_longit = merge_events(df_longit)

    # Write result to output
    logger.info(f"Writing merged and filtered input data to HDF5 file {output_path}")
    df_fevent.to_hdf(output_path, "/first_event")
    df_longit.to_hdf(output_path, "/longit")


def load_data(first_event_path, longit_path, info_path):
    """Load the first-event and longitudinal data"""
    logger.info("Loading first-event and longitudinal data")

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

    # Longitudinal data
    logger.debug("Loading and cleaning longitudinal data")
    df_longit = pd.read_csv(longit_path)
    df_longit = df_longit.astype({
        "FINNGENID": np.object,
        "EVENT_AGE": np.float64,
        "EVENT_YEAR": np.int64,
        "ENDPOINT": np.object,
    })

    # Loading data file with ID -> SEX info
    logger.debug("Loading info data")
    dfsex = pd.read_csv(
        info_path,
        dialect=excel_tab,
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

    # Add SEX information to longitudinal DataFrame
    # NOTE: for some individuals there is no sex information, so
    # "female" and "male" columns will be NaN and of type float64.
    logger.debug("Merging sex information into the DataFrames")
    df_longit = df_longit.merge(dfsex, on="FINNGENID", how="left")
    df_fevent = df_fevent.merge(dfsex, on="FINNGENID", how="left")

    return df_fevent, df_longit


def filter_out_samples(data, samples_path):
    """Filter out samples, select only the one included in PheWeb."""
    logger.info("Filtering out the samples.")
    (nbefore, _) = data.shape
    samples = pd.read_csv(samples_path, dialect=excel_tab, usecols=["FINNGENID"])
    data = data.merge(samples, on="FINNGENID")
    (nafter, _) = data.shape

    log_event_reduction(nbefore, nafter)
    return data


def get_filtered_endpoints(filepath):
    """Get endpoints that are not too broad"""
    df = pd.read_csv(
        filepath,
        dialect=excel_tab,
        usecols=["NAME", "OMIT", "LEVEL", "TAGS"],
        skiprows=[1]  # this row contains the comment info on the file version
    )
    mask_level = df["LEVEL"] != '1'
    mask_omit = df["OMIT"].isna()

    comorb = df["TAGS"].apply(is_comorb)
    mask_comorb = ~comorb

    df = df[mask_level & mask_omit & mask_comorb]
    endpoints = list(df.NAME.values)

    return endpoints


def filter_out_endpoints(df, endpoints):
    """Filter out data based on the given endpoints"""
    df_endpoints = pd.DataFrame({"ENDPOINT": endpoints})

    (nbefore, _) = df.shape
    df = df.merge(df_endpoints, on="ENDPOINT")
    (nafter, _) = df.shape

    log_event_reduction(nbefore, nafter)

    return df


def log_event_reduction(nbefore, nafter):
    logger.debug(f"Data reduced from {nbefore} to {nafter} (𝚫 = {nbefore - nafter}, {(nbefore - nafter) / nbefore * 100:.1f} %)")


def is_comorb(tags):
    """Return True if the endpoint is a comorbidity, False otherwise."""
    comorb_suffix = "_CM"
    tags = tags.split(",")
    tags = map(lambda tag: tag.endswith(comorb_suffix), tags)
    return all(tags)


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
    DATA_DIR = Path(argv[1])

    main(
        DATA_DIR / INPUT_FIRST_EVENT,
        DATA_DIR / INPUT_LONGIT,
        DATA_DIR / INPUT_INFO,
        DATA_DIR / INPUT_ENDPOINTS,
        DATA_DIR / INPUT_SAMPLES,
        DATA_DIR / OUTPUT_NAME,
    )
