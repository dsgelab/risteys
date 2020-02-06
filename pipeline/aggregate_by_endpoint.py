"""
Aggregate data by endpoint on a couple of metrics, for female, male and all sex.

Usage:
    python aggregate_by_endpoint.py <path-to-input> <output-path>

Output:
- stats.df5: HDF5 file with statistics and distributions for each endpoint
"""
from pathlib import Path
from sys import argv

import numpy as np
import pandas as pd

from log import logger


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


def main(input_path, output_path):
    """Compute statistics on input data and put them into an HDF5 file"""
    # Loading input data
    df_fevent = pd.read_hdf(input_path, "/first_event")
    df_longit = pd.read_hdf(input_path, "/longit")
    stats = pd.DataFrame()

    # Building up the aggregated statisitcs by endpoint
    stats = compute_prevalence(df_fevent, stats)
    stats.to_hdf(output_path, "/stats")

    stats = compute_mean_age(df_fevent, stats)
    stats.to_hdf(output_path, "/stats")

    stats = compute_case_fatality(df_fevent, stats)
    stats.to_hdf(output_path, "/stats")

    stats = compute_median_events(df_longit, stats)  # needs longitudinal data
    stats.to_hdf(output_path, "/stats")

    stats = compute_recurrence(df_longit, stats)  # needs longitudinal data
    stats.to_hdf(output_path, "/stats")

    # Making the distributions by endpoint
    distrib_age = compute_age_distribution(df_fevent)
    logger.debug("Writing age distribution to HDF5")
    distrib_age.to_hdf(output_path, "/distrib/age")

    distrib_year = compute_year_distribution(df_fevent)
    logger.debug("Writing year distribution to HDF5")
    distrib_year.to_hdf(output_path, "/distrib/year")

    # Checking that we don't miss any column with individual-level data
    expected_columns = set(ALL_COLS + FEMALE_COLS + MALE_COLS)
    assert set(stats.columns) == set(expected_columns), f"Mismatch while checking that all columns with individual-level are covered: {set(expected_columns)} != {set(stats.columns)}"

    # Filtering the data to remove individual-level data
    filter_stats(stats)
    stats.to_hdf(output_path, "/stats")

    filter_distrib(distrib_age)
    distrib_age.to_hdf(output_path, "/distrib/age")

    filter_distrib(distrib_year)
    distrib_year.to_hdf(output_path, "/distrib/year")

    logger.info("Done.")


def compute_prevalence(df, outdata):
    """Compute the prevalence by endpoint for sex=all,female,male

    NOTE:
    The sex information is missing for some individual, so it cannot
    be assumed that females + males = all.
    """
    # Count total number of individuals by sex
    logger.info("Computing count by sex")
    count_all = df.FINNGENID.unique().shape[0]
    count_female = df.loc[df.female > 0, "FINNGENID"].unique().shape[0]
    count_male = df.loc[df.male > 0, "FINNGENID"].unique().shape[0]

    # Number of individuals / endpoint for prevalence
    logger.info("Computing un-adjusted prevalence")
    count_by_endpoint_all = (
        df
        .groupby(["ENDPOINT", "FINNGENID"])
        .first()
        .groupby("ENDPOINT")
        .AGE  # to select just one column, but any column will lead to the same result
        .count()
    )
    count_by_endpoint_sex = (
        df
        .groupby(["ENDPOINT", "FINNGENID"])
        .first()
        .groupby("ENDPOINT")
        .sum()
    )
    count_by_endpoint_female = count_by_endpoint_sex["female"]
    count_by_endpoint_female = count_by_endpoint_female.astype(np.int)
    count_by_endpoint_male = count_by_endpoint_sex["male"]
    count_by_endpoint_male = count_by_endpoint_male.astype(np.int)

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
        ["AGE"]
        .min()
        .groupby("ENDPOINT")
        .mean()
    )

    # sex: female
    outdata["mean_age_female"] = (
        df[df.female > 0]
        .groupby(["ENDPOINT", "FINNGENID"])
        ["AGE"]
        .min()
        .groupby("ENDPOINT")
        .mean()
    )

    # sex: male
    outdata["mean_age_male"] = (
        df[df.male > 0]
        .groupby(["ENDPOINT", "FINNGENID"])
        ["AGE"]
        .min()
        .groupby("ENDPOINT")
        .mean()
    )

    return outdata


def compute_case_fatality(df, outdata):
    """Compute the 5-year case fatality rate"""
    logger.info("Computing 5-year case fatality rate")
    window = 5  # in years
    # Finding death event for all individuals
    logger.info("Finding death event for all individuals")
    deaths = (
        df.loc[df.ENDPOINT == "DEATH", ["FINNGENID", "AGE"]]
        .rename(columns={"AGE": "DEATH_AGE"})
    )
    assert (~ deaths.FINNGENID.duplicated()).all(), "Some individuals with more than 1 death"

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
        ["AGE", "DEATH_AGE"]
        .first()
    )
    stat = (stat["DEATH_AGE"] - stat["AGE"]) < window
    stat = (
        stat
        .groupby("ENDPOINT")
        .agg(lambda g: g[g == True].count() / g.count())
    )
    outdata["case_fatality_all"] = stat

    # sex: female
    stat = (
        df[df.female > 0]
        .groupby(["ENDPOINT", "FINNGENID"])
        ["AGE", "DEATH_AGE"]
        .first()
    )
    stat = (stat["DEATH_AGE"] - stat["AGE"]) < window
    stat = (
        stat
        .groupby("ENDPOINT")
        .agg(lambda g: g[g == True].count() / g.count()))
    outdata["case_fatality_female"] = stat

    # sex: male
    stat = (
        df[df.male > 0]
        .groupby(["ENDPOINT", "FINNGENID"])
        ["AGE", "DEATH_AGE"]
        .first()
    )
    stat = (stat["DEATH_AGE"] - stat["AGE"]) < window
    stat = (
        stat
        .groupby("ENDPOINT")
        .agg(lambda g: g[g == True].count() / g.count()))
    outdata["case_fatality_male"] = stat

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


def compute_recurrence(df, outdata):
    """Compute the recurrence rate within 6 months"""
    logger.info("Computing recurrence within 6 months")
    window = 0.5  # in years, we assume the EVENT_AGE column is in years also

    # Sex: all
    outdata["reoccurence_all"] = _recurrence_sex(df, window)
    # Sex: female
    outdata["reoccurence_female"] = _recurrence_sex(df[df.female == 1], window)
    # Sex: male
    outdata["reoccurence_male"] = _recurrence_sex(df[df.male == 1], window)

    return outdata


def _recurrence_sex(df, window):
    """Given a whole data frame, compute the recurrence rate for each endpoint.

    This function doesn't use a groupby() to find recurrent events,
    which is faster.  Instead it relies on the given data frame being
    already sorted.

    NOTE: We assume that for an endpoint, the events of an individual
    are already sorted by EVENT_AGE, otherwise results will be wrong.
    """
    shifted = df.shift()
    diff_age = df.EVENT_AGE - shifted.EVENT_AGE
    recurrence_rows = (
        (df.FINNGENID == shifted.FINNGENID)
        & (df.ENDPOINT == shifted.ENDPOINT)
        & (diff_age <= window)
    )

    count_recurrence = df[recurrence_rows].groupby("ENDPOINT")["FINNGENID"].nunique()
    count_all = df.groupby("ENDPOINT")["FINNGENID"].nunique()

    return count_recurrence / count_all


def compute_age_distribution(df):
    """Compute the age distribution of first event for each endpoint.

    Pre-defined age brackets:
    0-9, 10-19, 20-29, 30-39, 40-49, 50-59, 60-69, 70-79, 80-89, 90+
    """
    logger.info("Computing age distributions")
    brackets = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, np.inf]
    return compute_distrib(df, "AGE", brackets)


def compute_year_distribution(df):
    """Compute the events year distribution for each endpoint"""
    logger.info("Computing year distributions")
    brackets = [np.NINF, 1970, 1975, 1980, 1985, 1990, 1995, 2000, 2005, 2010, 2015, np.inf]
    df = compute_distrib(df, "YEAR", brackets)
    return df


def compute_distrib(df, column, brackets):
    """Compute a distribution of the values in the given column.

    The distributions are computed by endpoint for sexs: all, female, male.

    Arguments:
    - df: pd.DataFrame
      data source that contains the values
    - column: string
      name of the column with the data that we will compute the distribution on
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
        .first()
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
        .first()
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
        .first()
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
    INPUT = Path(argv[1])
    OUTPUT = Path(argv[2])

    main(INPUT, OUTPUT)
