"""
Performs quality control of the input data.

Usage:
    python qc.py <path-to-data-dir>

Input Files:
- FINNGEN_MINIMUM_DATA.txt
  Each row is an individual in FinnGen with some information.
  Source: FinnGen data
- FINNGEN_PHENOTYPES.txt
  Each row is an individual, columns are endpoint data.
  Source: FinnGen data
- FINNGEN_ENDPOINTS_longitudinal.txt
  Each row is an event with FinnGen ID, Endpoint and time information.
  Source: FinnGen data
"""

from csv import excel_tab
from pathlib import Path
from sys import argv

import pandas as pd

from log import logger


INPUT_INFO = "FINNGEN_MINIMUM_DATA.txt"
INPUT_FIRST_EVENT = "FINNGEN_PHENOTYPES.txt"
INPUT_LONGIT = "FINNGEN_ENDPOINTS_longitudinal.txt"
OUTPUT_FILE = "qc.hdf5"


def prechecks(info_path, first_event_path, longit_path, output_path):
    """Make sure input files exist and output file doesn't"""
    logger.info("Performing pre-checks")
    assert info_path.exists(), f"{info_path} doesn't exist"
    assert first_event_path.exists(), f"{first_event_path} doesn't exist"
    assert longit_path.exists(), f"{longit_path} doesn't exist"
    assert not output_path.exists(), f"{output_path} already exists"


def main(info_path, first_event_path, longit_path, output_path):
    """Check the data for quality control"""
    prechecks(
        info_path,
        first_event_path,
        longit_path,
        output_path
    )

    # Load the data
    logger.info("Loading the data")
    df_info = pd.read_csv(
        info_path,
        dialect=excel_tab,
        usecols=["FINNGENID", "BL_YEAR", "BL_AGE", "SEX"]
    )

    df_first_event = pd.read_csv(
        first_event_path,
        dialect=excel_tab,
        usecols=["FINNGENID", "DEATH", "DEATH_AGE", "FU_END_AGE"]
    )

    df_longit = pd.read_csv(
        longit_path,
        dialect=excel_tab,
    )

    # QC for info file
    logger.info("Performing QC for the minimum info file")
    check_year(df_info)
    check_age(df_info)
    check_sex(df_info)

    # QC for first-event file
    logger.info("Performing QC for the first-event file")
    check_age_death(df_first_event)

    # QC for longitudinal file
    logger.info("Performing QC for the longitudinal file")
    try:
        check_no_duplicates(df_longit)
    except AssertionError:
        logger.warning("Found duplicates in longitudinal file, cleaning.")
        df_longit = remove_duplicates(df_longit)

    # Output QCed data
    logger.info("Writing out the QCed data")
    df_info.to_hdf(output_path, "/info")
    df_first_event.to_hdf(output_path, "/first_event")
    df_longit.to_hdf(output_path, "/longit")


def check_year(df):
    """Check "year" in the data is less than 2020.

    NOTE: the year will increase as new FinnGen data is released.
    """
    assert (df.BL_YEAR < 2020).all()


def check_age(df):
    """Check that individuals age is in a plausible range"""
    assert (df.BL_AGE < 120).all()
    assert (df.BL_AGE > 0).all()


def check_sex(df):
    """Check that sex is either female or male"""
    assert set(df.SEX) == {'male', 'female'}


def check_age_death(df):
    """Check that age at death happens before end of follow-up"""
    died = df[df.DEATH == 1]
    assert (died.DEATH_AGE <= died.FU_END_AGE).all()


def check_no_duplicates(df):
    """Check that the longitudinal data file has no duplicate entries"""
    dups = df.duplicated(keep=False)
    assert (~ dups).all()  # True means there is no duplicate entries


def remove_duplicates(df):
    """Remove duplicated entries from the longitudinal file"""
    return df.drop_duplicates()


if __name__ == '__main__':
    DATA_DIR = Path(argv[1])

    main(
        DATA_DIR / INPUT_INFO,
        DATA_DIR / INPUT_FIRST_EVENT,
        DATA_DIR / INPUT_LONGIT,
        DATA_DIR / OUTPUT_FILE
    )
