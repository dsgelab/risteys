"""
Performs quality control of the input data.

Usage:
    python qc.py <path-to-info> <path-to-first-events> <output-path>

Input Files:
- Info Data
  Each row is an individual in FinnGen with some information.
  Source: FinnGen data
- First Events
  Each row is an individual, columns are endpoint data.
  Source: FinnGen data
"""

from pathlib import Path
from sys import argv

import pandas as pd

from risteys_pipeline.log import logger


SAMPLE_YEAR_LESS_THAN = 2022


def main(info_path, first_event_path):
    """Check the data for quality control"""
    qc_info_file(info_path)
    qc_first_event_file(first_event_path)


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


def check_year(df):
    """Check "year" in the minimum info file is valid.

    In the minimum info file, BL_YEAR should be equal or less than the
    current year.

    NOTE: the year will increase as new FinnGen data is released.
    """
    assert (df.BL_YEAR < SAMPLE_YEAR_LESS_THAN).all()


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


if __name__ == '__main__':
    INFO = Path(argv[1])
    FIRST_EVENTS = Path(argv[2])
    main(
        INFO,
        FIRST_EVENTS
    )
