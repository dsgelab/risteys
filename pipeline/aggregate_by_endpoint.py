"""
Aggregate data by endpoint on a couple of metrics, for female, male and all sex.

Usage:
    python aggregate_by_endpoint.py <path-to-data-dir>

Output:
- stats.df5: HDF5 file with statistics and distributions for each endpoint
"""
from csv import excel_tab
from pathlib import Path
from sys import argv

import numpy as np
import pandas as pd

from log import logger


# Input / output files
INPUT_FILENAME = "input.hdf5"
OUTPUT_FILENAME = "stats.hdf5"

# Treshold below which data is considered individual-level data
INDIV_TRESHOLD = 6

# Columns where we will remove data if it contains individual-level data
ALL_COLS = [
    "nindivs_all",
    "prevalence_all",
    "mean_age_all",
    "median_events_all",
    "reoccurence_all",
    "case_fatality_all",
]
FEMALE_COLS = [
    "nindivs_female",
    "prevalence_female",
    "mean_age_female",
    "median_events_female",
    "reoccurence_female",
    "case_fatality_female",
]
MALE_COLS = [
    "nindivs_male",
    "prevalence_male",
    "mean_age_male",
    "median_events_male",
    "reoccurence_male",
    "case_fatality_male",
]


def prechecks(input_file):
    """Perform checks before running to fail earlier rather than later"""
    logger.info("Performing pre-checks")
    assert input_file.exists(), f"{input_file} doesn't exist"
    assert not OUTPUT_PATH.exists(), f"{OUTPUT_PATH} already exists, not overwritting it"
    assert not OUTPUT_RECOVERY.exists(), f"{OUTPUT_RECOVERY} already exists, not overwritting it"


def main(input_path):
    """Compute statistics on input data and put them into an HDF5 file"""
    prechecks(input_path)

    # Loading input data
    indata = pd.read_hdf(input_path)
    stats = pd.DataFrame()

    # Building up the aggregated statisitcs by endpoint
    stats = compute_prevalence(indata, stats)
    stats.to_hdf(OUTPUT_RECOVERY, "/stats")

    stats = compute_mean_age(indata, stats)
    stats.to_hdf(OUTPUT_RECOVERY, "/stats")

    stats = compute_median_events(indata, stats)
    stats.to_hdf(OUTPUT_RECOVERY, "/stats")

    stats = compute_reoccurence(indata, stats)
    stats.to_hdf(OUTPUT_RECOVERY, "/stats")

    stats = compute_case_fatality(indata, stats)
    stats.to_hdf(OUTPUT_RECOVERY, "/stats")

    # Making the distributions by endpoint
    distrib_age = compute_age_distribution(indata)
    logger.debug("Writing age distribution to HDF5")
    distrib_age.to_hdf(OUTPUT_RECOVERY, "/distrib/age")

    distrib_year = compute_year_distribution(indata)
    logger.debug("Writing year distribution to HDF5")
    distrib_year.to_hdf(OUTPUT_RECOVERY, "/distrib/year")

    # Checking that we don't miss any column with individual-level data
    expected_columns = set(ALL_COLS + FEMALE_COLS + MALE_COLS)
    assert set(stats.columns) == set(expected_columns), f"Mismatch while checking that all columns with individual-level are covered: {set(expected_columns)} != {set(stats.columns)}"

    # Filtering the data to remove individual-level data
    filter_stats(stats)
    stats.to_hdf(OUTPUT_RECOVERY, "/stats")

    filter_distrib(distrib_age)
    distrib_age.to_hdf(OUTPUT_RECOVERY, "/distrib/age")

    filter_distrib(distrib_year)
    distrib_year.to_hdf(OUTPUT_RECOVERY, "/distrib/year")


    # Everything went fine, moving recovery file to proper output path
    OUTPUT_RECOVERY.rename(OUTPUT_PATH)

    logger.info("Done.")


def compute_prevalence(df, outdata):
    """Compute the prevalence by endpoint for sex=all,female,male"""
    # Count total number of individuals by sex
    logger.info("Computing count by sex")
    count_by_sex = (df.groupby("FINNGENID")
                    [["female", "male"]]
                    .first())
    count_female = count_by_sex["female"].sum()
    count_male = count_by_sex["male"].sum()
    count_all = count_female + count_male
    check_count_all = df["FINNGENID"].unique().size
    assert count_all == check_count_all, f"Counts for sex 'all' defer: {count_all} != {check_count_all}"

    # Number of individuals / endpoint for prevalence
    logger.info("Computing un-adjusted prevalence")
    count_by_endpoint = (df.groupby(["ENDPOINT", "FINNGENID"])
                         .first()
                         .groupby("ENDPOINT")
                         .sum())
    count_by_endpoint_female = count_by_endpoint["female"]
    count_by_endpoint_male = count_by_endpoint["male"]
    count_by_endpoint_all = count_by_endpoint_female + count_by_endpoint_male

    # Add number of individuals to the output DataFrame
    outdata["nindivs_all"] = count_by_endpoint_all
    outdata["nindivs_female"] = count_by_endpoint_female
    outdata["nindivs_male"] = count_by_endpoint_male

    # Compute and add prevalence to the output DataFrame
    outdata["prevalence_all"] = count_by_endpoint_all / count_all
    outdata["prevalence_female"] = count_by_endpoint_female / count_female
    outdata["prevalence_male"] = count_by_endpoint_male / count_male

    return outdata


def compute_mean_age(df, outdata):
    """Compute the mean age at first event for each endpoint"""
    logger.info("Computing mean age at first event")

    # sex: all
    outdata["mean_age_all"] = (
        df
        .groupby(["ENDPOINT", "FINNGENID"])
        ["EVENT_AGE"]
        .min()
        .groupby("ENDPOINT")
        .mean()
    )

    # sex: female
    outdata["mean_age_female"] = (
        df[df["female"] == 1]
        .groupby(["ENDPOINT", "FINNGENID"])
        ["EVENT_AGE"]
        .min()
        .groupby("ENDPOINT")
        .mean()
    )

    # sex: male
    outdata["mean_age_male"] = (
        df[df["male"] == 1]
        .groupby(["ENDPOINT", "FINNGENID"])
        ["EVENT_AGE"]
        .min()
        .groupby("ENDPOINT")
        .mean()
    )

    return outdata


def compute_median_events(df, outdata):
    """Compute the median number of events by individual for each endpoint"""
    logger.info("Computing median number of events")

    # sex: all
    outdata["median_events_all"] = (
        df
        .groupby(["ENDPOINT", "FINNGENID"])
        ["EVENT_YEAR"].count()  # could have selected any column as we just count events
        .groupby("ENDPOINT")
        .median()
    )

    # sex: female
    outdata["median_events_female"] = (
        df[df["female"] == 1]
        .groupby(["ENDPOINT", "FINNGENID"])
        ["EVENT_YEAR"].count()
        .groupby("ENDPOINT")
        .median()
    )

    # sex: male
    outdata["median_events_male"] = (
        df[df["male"] == 1]
        .groupby(["ENDPOINT", "FINNGENID"])
        ["EVENT_YEAR"].count()
        .groupby("ENDPOINT")
        .median()
    )

    return outdata


def compute_reoccurence(df, outdata):
    """Compute the reoccurence rate within 6 months"""
    logger.info("Computing re-occurence within 6 months")
    window = 0.5  # in years, we assume the EVENT_AGE column is in years also

    # sex: all
    outdata["reoccurence_all"] = (
        df.groupby(["ENDPOINT", "FINNGENID"])
        ["EVENT_AGE"]
        .agg(lambda ages: any_reoccurence(ages, window))
        .groupby("ENDPOINT")
        # For each endpoint, count the number of individuals with reoccurence / total individuals
        .agg(lambda g: g[g == True].count() / g.count())
    )

    # sex: female
    outdata["reoccurence_female"] = (
        df[df["female"] == 1]
        .groupby(["ENDPOINT", "FINNGENID"])
        ["EVENT_AGE"]
        .agg(lambda ages: any_reoccurence(ages, window))
        .groupby("ENDPOINT")
        .agg(lambda g: g[g == True].count() / g.count())
    )

    # sex: male
    outdata["reoccurence_male"] = (
        df[df["male"] == 1]
        .groupby(["ENDPOINT", "FINNGENID"])
        ["EVENT_AGE"].agg(lambda ages: any_reoccurence(ages, window))
        .groupby("ENDPOINT")
        .agg(lambda g: g[g == True].count() / g.count())
    )

    return outdata


def any_reoccurence(events, window):
    """Check if any two events happened within a given time window.

    NOTE: We assume that events are already sorted by
    [FINNGENID, EVENT_AGE], so we don't perform a sort.
    """
    # Diff between a value and the next one
    shifted = events.shift(-1)
    diff = events - shifted

    reoccurence = diff <= window
    return reoccurence.any()


def compute_case_fatality(df, outdata):
    """Compute the 5-year case fatality rate"""
    logger.info("Computing 5-year case fatality rate")
    window = 5  # in years

    # Finding death event for all individuals
    logger.info("Finding death event for all individuals")
    deaths = (
        df.loc[df.loc[:, "ENDPOINT"] == "DEATH"]
        .rename(columns={'EVENT_AGE': 'DEATH_AGE'})
        .drop(["EVENT_YEAR", "ENDPOINT", "female", "male"], axis=1)
    )

    # Individuals not dead are not in the "deaths" DataFrame so using
    # the default inner-join would remove all of them from the merged
    # DataFrame. We want to keep them so we use a left-join.
    logger.debug("Merging death event into DataFrame")
    df = df.merge(deaths, on="FINNGENID", how="left")

    logger.debug("Back to computing case fatality")
    # sex: all
    stat = (
        df
        .groupby(["ENDPOINT", "FINNGENID"])
        ["EVENT_AGE", "DEATH_AGE"]
        .min()
    )
    stat = stat["DEATH_AGE"] - stat["EVENT_AGE"] < window
    stat = (
        stat
        .groupby("ENDPOINT")
        .agg(lambda g: g[g == True].count() / g.count())
    )
    outdata["case_fatality_all"] = stat

    # sex: female
    stat = (
        df[df["female"] == 1]
        .groupby(["ENDPOINT", "FINNGENID"])
        ["EVENT_AGE", "DEATH_AGE"]
        .min()
    )
    stat = stat["DEATH_AGE"] - stat["EVENT_AGE"] < 5
    stat = (
        stat
        .groupby("ENDPOINT")
        .agg(lambda g: g[g == True].count() / g.count()))
    outdata["case_fatality_female"] = stat

    # sex: male
    stat = (
        df[df["male"] == 1]
        .groupby(["ENDPOINT", "FINNGENID"])
        ["EVENT_AGE", "DEATH_AGE"]
        .min()
    )
    stat = stat["DEATH_AGE"] - stat["EVENT_AGE"] < 5
    stat = (
        stat
        .groupby("ENDPOINT")
        .agg(lambda g: g[g == True].count() / g.count()))
    outdata["case_fatality_male"] = stat

    return outdata


def compute_age_distribution(df):
    """Compute the age distribution of first event for each endpoint.

    Pre-defined age brackets:
    0-9, 10-19, 20-29, 30-39, 40-49, 50-59, 60-69, 70-79, 80-89, 90+
    """
    logger.info("Computing age distributions")
    brackets = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, np.inf]
    return compute_distrib(df, "EVENT_AGE", brackets)


def compute_year_distribution(df):
    """Compute the events year distribution for each endpoint"""
    logger.info("Computing year distributions")
    brackets = [np.NINF, 1970, 1975, 1980, 1985, 1990, 1995, 2000, 2005, 2010, 2015, np.inf]
    return compute_distrib(df, "EVENT_YEAR", brackets)


def compute_distrib(df, column, brackets):
    """Compute a distribution of the values in the given column.

    The distributions are computed by endpoint for sexs: all, female, male.

    Arguments:
    - df: pd.DataFrame
      data source that contains the values
    - column: string
      name of the column with the data taht we will compute the distribution on
    - brackets: list of numbers
      values at which the split the data for binning

    Output:
    - pd.Series with endpoints as index and distributions as values
    """
    outdata = pd.DataFrame()

    # sex: all
    outdata["all"] = (
        df
        .groupby(["ENDPOINT", "FINNGENID"])
        [column]
        .min()
        .groupby("ENDPOINT")
        # Perform binning for each row, then count how many occurences for each bin
        .apply(lambda g:
               pd.cut(g, brackets, right=False)
               .value_counts()
        )
    )

    # sex: female
    outdata["female"] = (
        df[df["female"] == 1]
        .groupby(["ENDPOINT", "FINNGENID"])
        [column]
        .min()
        .groupby("ENDPOINT")
        .apply(lambda g:
               pd.cut(g, brackets, right=False)
               .value_counts()
        )
    )

    # sex: male
    outdata["male"] = (
        df[df["male"] == 1]
        .groupby(["ENDPOINT", "FINNGENID"])
        [column]
        .min()
        .groupby("ENDPOINT")
        .apply(lambda g:
               pd.cut(g, brackets, right=False)
               .value_counts()
        )
    )

    return outdata


def filter_stats(stats):
    """Remove individual-level data in the statistics"""
    logger.info("Filtering out individual level data in the statistics")

    # sex: all
    stats.loc[
        (stats.loc[:, "nindivs_all"] < INDIV_TRESHOLD) & (stats.loc[:, "nindivs_all"] != 0),
        ALL_COLS + FEMALE_COLS + MALE_COLS
    ] = None

    # sex: female
    stats.loc[
        (stats.loc[:, "nindivs_female"] < INDIV_TRESHOLD) & (stats.loc[:, "nindivs_female"] != 0),
        FEMALE_COLS
    ] = None

    # sex: male
    stats.loc[
        (stats.loc[:, "nindivs_male"] < INDIV_TRESHOLD) & (stats.loc[:, "nindivs_male"] != 0),
        MALE_COLS
    ] = None


def filter_distrib(distrib):
    """Remove individual-level data in the bins of the given distribution"""
    logger.info("Filtering out individual-level data in a distribution")

    # sex: all
    distrib.loc[
        (distrib.loc[:, "all"] < INDIV_TRESHOLD) & (distrib.loc[:, "all"] != 0),
        "all"
    ] = None

    # sex: female
    distrib.loc[
        (distrib.loc[:, "female"] < INDIV_TRESHOLD) & (distrib.loc[:, "female"] != 0),
        "female"
    ] = None

    # sex: male
    distrib.loc[
        (distrib.loc[:, "male"] < INDIV_TRESHOLD) & (distrib.loc[:, "male"] != 0),
        "male"
    ] = None


if __name__ == '__main__':
    # Get filenames from the command line arguments
    DATA_DIR = Path(argv[1])
    INPUT_PATH = DATA_DIR / INPUT_FILENAME

    OUTPUT_PATH = DATA_DIR / OUTPUT_FILENAME
    OUTPUT_RECOVERY = OUTPUT_PATH.with_suffix(".hdf5.recovery")

    main(INPUT_PATH)
