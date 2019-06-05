"""
Aggregate data by endpoint on a couple of metrics, for female, male and all sex.

Usage:
    python aggregate_by_endpoint.py <data-file-longitudinal> <data-file-minimum-data> <output-dir>

For each endpoint we want the metrics (split by sex: all/female/male):
- number of individuals --> COUNT
- un-adjusted prevalence --> TOTAL number of individuals
- mean age at first-event --> AGE LIST
- median number of events by individual --> MAP {indiv -> count}
- re-occurence within 6 months --> MAP {indiv -> [LIST AGEs]}
- case fatality at 5 years --> MAP {indiv -> {first event: AGE, death: AGE}}
- age distribution --> AGE LIST
- year distribution --> YEAR LIST

Output:
- HDF5 file with statistics and distributions for each endpoint
"""
from csv import excel_tab
from pathlib import Path
from sys import argv

import numpy as np
import pandas as pd

from log import logger
from utils import file_exists


OUTPUT_FILENAME = "stats.hdf5"


def prechecks(longit_file, mindata_file):
    """Perform checks before running to fail earlier rather than later"""
    logger.info("Performing pre-checks")
    assert file_exists(longit_file), f"{longit_file} doesn't exist"
    assert file_exists(mindata_file), f"{mindata_file} doesn't exist"
    assert not file_exists(OUTPUT_FILEPATH), f"{OUTPUT_FILEPATH} already exists, not overwritting it"

    # Check event file headers
    df = pd.read_csv(longit_file, dialect=excel_tab, nrows=0)
    cols = list(df.columns)
    expected_cols = ["FINNGENID", "EVENT_AGE", "EVENT_YEAR", "ENDPOINT"]
    assert cols == expected_cols

    # Check sex for all individuals
    df = pd.read_csv(mindata_file, dialect=excel_tab, usecols=["FINNGENID", "SEX"])
    sexs = df["SEX"].unique()
    sexs = set(sexs)
    expected_sexs = set(["female", "male"])
    assert sexs == expected_sexs


def main(longit_file, mindata_file):
    """Compute statistics on input data and put them into and HDF5 file"""
    prechecks(longit_file, mindata_file)

    indata = parse_data(longit_file, mindata_file)

    outdata = pd.DataFrame()
    outdata = compute_prevalence(indata, outdata)

    outdata.to_hdf(OUTPUT_FILEPATH, "/stats")

    logger.info("Done.")


def parse_data(longit_file, mindata_file):
    """Load the input data into a DataFrame

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


def compute_prevalence(df, outdata):
    """Compute the prevalence by endpoint for sex=all,female,male"""
    # Count total number of individuals by sex
    logger.info("Computing: count by sex")
    count_by_sex = df.groupby("FINNGENID")
    count_by_sex = count_by_sex[["female", "male"]]
    count_by_sex = count_by_sex.first()
    count_female = count_by_sex["female"].sum()
    count_male = count_by_sex["male"].sum()
    count_all = count_female + count_male
    check_count_all = df["FINNGENID"].unique().size
    assert count_all == check_count_all, f"Counts for sex 'all' defer: {count_all} != {check_count_all}"

    # Un-adjusted prevalence
    logger.info("Computing: un-adjusted prevalence")
    count_by_endpoint = df.groupby(["ENDPOINT", "FINNGENID"]).first()
    count_by_endpoint = count_by_endpoint.groupby("ENDPOINT").sum()
    count_by_endpoint_female = count_by_endpoint["female"]
    count_by_endpoint_male = count_by_endpoint["male"]
    count_by_endpoint_all = count_by_endpoint_female + count_by_endpoint_male

    # Add prevalence to the output DataFrame
    outdata["prevalence_all"] = count_by_endpoint_all / count_all
    outdata["prevalence_female"] = count_by_endpoint_female / count_female
    outdata["prevalence_male"] = count_by_endpoint_male / count_male

    return outdata


if __name__ == '__main__':
    # Get filenames from the command line arguments
    LONGIT_FILE = Path(argv[1])
    MINDATA_FILE = Path(argv[2])
    OUTPUT_DIR = Path(argv[3])

    OUTPUT_FILEPATH = OUTPUT_DIR / OUTPUT_FILENAME

    main(LONGIT_FILE, MINDATA_FILE)
