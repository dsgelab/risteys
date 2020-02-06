"""
Performs quality control of the input data.

Usage:
    python qc.py <path-to-info> <path-to-first-events> <path-to-longitudinal> <output-path>

Input Files:
- Info Data
  Each row is an individual in FinnGen with some information.
  Source: FinnGen data
- First Events
  Each row is an individual, columns are endpoint data.
  Source: FinnGen data
- Longitudinal
  Each row is an event with FinnGen ID, Endpoint and time information.
  Source: FinnGen data

Output files:
- Longitudinal QCed
  CSV file with the same format as the original longitudinal file, but
  with QC applied.
"""

from pathlib import Path
from sys import argv

import pandas as pd

from log import logger


def main(info_path, first_event_path, longit_path, longit_output_path):
    """Check the data for quality control"""
    qc_info_file(info_path)
    qc_first_event_file(first_event_path)
    qc_longit_file(longit_path, longit_output_path)


def qc_info_file(input_path):
    logger.info("Performing QC for minimum info file")

    df_info = pd.read_csv(
        input_path,
        usecols=["FINNGENID", "BL_YEAR", "BL_AGE", "SEX"]
    )

    check_year(df_info)
    check_age(df_info)
    check_sex(df_info)


def qc_first_event_file(input_path):
    logger.info("Performing QC for the first-event file")

    df_first_event = pd.read_csv(
        input_path,
        usecols=["DEATH", "DEATH_AGE", "FU_END_AGE"]  # speed-up the parsing
    )

    check_age_death(df_first_event)


def qc_longit_file(input_path, output_path):
    logger.info("Performing QC for the longitudinal file")

    df_longit = pd.read_csv(input_path)

    try:
        check_no_duplicates(df_longit)
    except AssertionError:
        logger.warning("Found duplicates in longitudinal file, cleaning.")
        df_longit = remove_duplicates(df_longit)

    df_longit.to_csv(output_path, index=False, mode="x")


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
    INFO = Path(argv[1])
    FIRST_EVENTS = Path(argv[2])
    LONGIT = Path(argv[3])
    OUTPUT = Path(argv[4])
    main(
        INFO,
        FIRST_EVENTS,
        LONGIT,
        OUTPUT
    )
