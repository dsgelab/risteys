"""
Takes the input CSV files and merge them into one HDF5 file.

Also performs filtering of the endpoints that are too broad.

Usage:
    python build_input_hdf.py <path-to-data-dir>
"""
from csv import excel_tab
from pathlib import Path
from sys import argv

import numpy as np
import pandas as pd

from log import logger


INPUT_LONGIT = "FINNGEN_ENDPOINTS_longitudinal.txt"
INPUT_INFO = "FINNGEN_MINIMUM_DATA.txt"
INPUT_ENDPOINTS = "Endpoint_definitions_FINNGEN_ENDPOINTS.tsv"
OUTPUT_NAME = "input.hdf5"


def prechecks(endpoints_path, longit_path, info_path, output_path):
    """Perform checks before running to fail earlier rather than later"""
    logger.info("Performing pre-checks")
    assert endpoints_path.exists()
    assert longit_path.exists()
    assert info_path.exists()
    assert not output_path.exists()

    # Check endpoint file headers
    df = pd.read_csv(endpoints_path, dialect=excel_tab, nrows=0)
    assert "NAME" in df.columns
    assert "OMIT" in df.columns
    assert "LEVEL" in df.columns
    
    # Check event file headers
    df = pd.read_csv(longit_path, dialect=excel_tab, nrows=0)
    cols = list(df.columns)
    expected_cols = ["FINNGENID", "EVENT_AGE", "EVENT_YEAR", "ENDPOINT"]
    assert cols == expected_cols

    # Check sex for all individuals
    df = pd.read_csv(info_path, dialect=excel_tab, usecols=["FINNGENID", "SEX"])
    sexs = df["SEX"].unique()
    sexs = set(sexs)
    expected_sexs = set(["female", "male"])
    assert sexs == expected_sexs


def main(endpoints_path, longit_path, info_path, output_path):
    """Clean up and merge all the input files into one HDF5 file"""
    prechecks(endpoints_path, longit_path, info_path, output_path)

    endpoints = get_endpoints(endpoints_path)

    data = parse_data(longit_path, info_path)

    logger.info("Filtering out the endpoints that are too broad")
    data = data.merge(endpoints, on="ENDPOINT")

    logger.info(f"Writing merged and filtered input data to HDF5 file {output_path}")
    data.to_hdf(output_path, "/data")


def get_endpoints(filepath):
    """Get endpoints that are not too broad"""
    df = pd.read_csv(
        filepath,
        dialect=excel_tab,
        usecols=["NAME", "OMIT", "LEVEL"],
        skiprows=[1]  # this row contains the comment info on the file version
    )
    mask_level = df["LEVEL"] != '1'
    mask_omit = df["OMIT"].isna()
    df = df[mask_level & mask_omit]
    df = df.drop(["OMIT", "LEVEL"], axis="columns").rename({"NAME": "ENDPOINT"}, axis="columns")
    return df


def parse_data(longit_file, mindata_file):
    """Parse the events file and mindata file to build a coherent DataFrame.

    NOTE:
    At this point we might want to write out the loaded data as a
    DataFrame so it can be re-loaded later on. However doing this adds
    the cost for: writing out the DataFrame the first time + loading
    the DataFrame each time. After few measurements it turns out this
    doesn't save that much time.
    """
    logger.info("Parsing 'longitudinal file' and 'mininimum data file' into DataFrames")
    df = pd.read_csv(
        longit_file,
        dialect=excel_tab,
        dtype={
            "FINNGENID": np.object,
            "EVENT_AGE": np.float64,
            "EVENT_YEAR": np.int64,
            "ENDPOINT": np.object,
    })

    # Loading data file with ID -> SEX info
    dfsex = pd.read_csv(
        mindata_file,
        dialect=excel_tab,
        usecols=["FINNGENID", "SEX"],
        dtype={
            "FINNGENID": np.object,
            "SEX": "category",
    })

    # Perform one-hot encoding for SEX so it can be written to HDF
    # without the slow format="table".
    onehot = pd.get_dummies(dfsex["SEX"])
    dfsex = pd.concat([dfsex, onehot], axis=1)
    dfsex = dfsex.drop("SEX", axis=1)

    logger.debug("Merging longitudinal and sex DataFrames")
    df = df.merge(dfsex, on="FINNGENID")

    return df


if __name__ == '__main__':
    DATA_DIR = Path(argv[1])
    INPUT_LONGIT_PATH = DATA_DIR / INPUT_LONGIT
    INPUT_INFO_PATH = DATA_DIR / INPUT_INFO
    INPUT_ENDPOINTS_PATH = DATA_DIR / INPUT_ENDPOINTS
    OUTPUT_PATH = DATA_DIR / OUTPUT_NAME

    main(INPUT_ENDPOINTS_PATH, INPUT_LONGIT_PATH, INPUT_INFO_PATH, OUTPUT_PATH)
