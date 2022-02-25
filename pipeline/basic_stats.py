"""
Basic summary statistics for endpoints, computed for female, male and all sex.

Usage:
    python basic_stats.py --help

Output:
- stats.json: JSON file with statistics and distributions for each endpoint
"""
import argparse
import json
from collections import defaultdict
from pathlib import Path
from sys import argv

import numpy as np
import pandas as pd

from log import logger


# Values which are considered individual-level data
INDIV_LEVELS = {1, 2, 3, 4}

# Columns where we will remove data if it contains individual-level data
ALL_COLS = [
    "nindivs_all",
    "prevalence_all",
    "mean_age_all",
]
FEMALE_COLS = [
    "nindivs_female",
    "prevalence_female",
    "mean_age_female",
]
MALE_COLS = [
    "nindivs_male",
    "prevalence_male",
    "mean_age_male",
]


def main():
    """Compute statistics on input data and put them into an HDF5 file"""
    args = cli_parser()

    df_fevents = load_filter_data(
        args.dense_first_events,
        args.filter_individuals,
        args.minimum_phenotypes
    )

    stats = pd.DataFrame()

    # Get the latest year of events in the data
    max_year = df_fevents.YEAR.max()

    # Building up the aggregated statisitcs by endpoint
    stats = compute_prevalence(df_fevents, stats)
    stats = compute_mean_age(df_fevents, stats)

    # Making the distributions by endpoint
    distrib_age = compute_age_distribution(df_fevents)
    distrib_year = compute_year_distribution(df_fevents, max_year)

    # Checking that we don't miss any column with individual-level data
    expected_columns = set(ALL_COLS + FEMALE_COLS + MALE_COLS)
    assert set(stats.columns) == set(expected_columns), f"Mismatch while checking that all columns with individual-level are covered: {set(expected_columns)} != {set(stats.columns)}"

    # Filtering the data to remove individual-level data
    filter_stats(stats)
    check_distrib_green(distrib_age)
    check_distrib_green(distrib_year)

    # Output all stats to a JSON file
    logger.info(f"Writing output data to JSON file {args.output}")

    stats = stats.to_dict(orient='index')
    distrib_age = dict_distrib(distrib_age)
    distrib_year = dict_distrib(distrib_year)

    with open(args.output, 'x') as out_file:
        json.dump({
            "stats": stats,
            "distrib_age": distrib_age,
            "distrib_year": distrib_year
        }, out_file)

    logger.info("Done.")


def cli_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '-d', '--dense-first-events',
        help="path to 'densified' first-events phenotype file (Feather v2)",
        required=True,
        type=Path
    )
    parser.add_argument(
        '-f', '--filter-individuals',
        help="path to file containing ID list of individuals to use (CSV)",
        required=False,
        type=Path
    )
    parser.add_argument(
        '-m', '--minimum-phenotypes',
        help="path to 'minimum phenotypes' file (CSV)",
        required=True,
        type=Path
    )
    parser.add_argument(
        '-o', '--output',
        help='path to output file (JSON)',
        required=True,
        type=Path
    )
    args = parser.parse_args()
    return args


def load_filter_data(first_events, filter_individuals, minimum_phenotypes):
    """Load, filter and merge data into single dataframe."""
    df_fevents = pd.read_feather(first_events)

    # Filter individuals
    df_filter_indivs = pd.read_csv(filter_individuals, usecols=["FINNGENID"])
    df_fevents = df_fevents.loc[df_fevents.FINNGENID.isin(df_filter_indivs.FINNGENID), :]

    # Add sex information
    df_mpheno = pd.read_csv(
        minimum_phenotypes,
        usecols=["FINNGENID", "SEX"]
    )
    df_mpheno = df_mpheno.rename(columns={"SEX": "sex"})
    df_mpheno = df_mpheno.astype({"sex": "category"})

    df_fevents = df_fevents.merge(df_mpheno, on="FINNGENID", how="left")

    return df_fevents


def compute_prevalence(df, outdata):
    """Compute the prevalence by endpoint for sex=all,female,male

    NOTE:
    The sex information is missing for some individual, so it cannot
    be assumed that females + males = all.
    """
    # Count total number of individuals by sex
    logger.info("Computing count by sex")
    count_all = df.FINNGENID.unique().shape[0]
    count_female = df.loc[df.sex == "female", "FINNGENID"].unique().shape[0]
    count_male = df.loc[df.sex == "male", "FINNGENID"].unique().shape[0]

    # Number of individuals / endpoint for prevalence
    logger.info("Computing un-adjusted prevalence")
    grouped = (
        df
        .groupby(["ENDPOINT", "FINNGENID"])
        .first()  # group multiple events with same ENDPOINT and FGID into 1 record
    )
    count_by_endpoint_all = (
        grouped
        .groupby("ENDPOINT")
        .sex  # to select just one column, but any column will lead to the same result
        .count()
    )
    count_by_endpoint_female = (
        grouped
        .loc[grouped.sex == "female", :]
        .groupby("ENDPOINT")
        .sex
        .count()
    )
    count_by_endpoint_male = (
        grouped
        .loc[grouped.sex == "male", :]
        .groupby("ENDPOINT")
        .sex
        .count()
    )

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

    grouped = (
        df
        .groupby(["ENDPOINT", "FINNGENID"])
        .first()
    )

    # sex: all
    outdata["mean_age_all"] = (
        grouped
        .AGE
        .groupby("ENDPOINT")
        .mean()
    )

    # sex: female
    outdata["mean_age_female"] = (
        grouped
        .loc[grouped.sex == "female", "AGE"]
        .groupby("ENDPOINT")
        .mean()
    )

    # sex: male
    outdata["mean_age_male"] = (
        grouped
        .loc[grouped.sex == "male", "AGE"]
        .groupby("ENDPOINT")
        .mean()
    )

    return outdata


def compute_age_distribution(df):
    """Compute the age distribution of first event for each endpoint.

    Pre-defined age brackets:
    0-9, 10-19, 20-29, 30-39, 40-49, 50-59, 60-69, 70-79, 80-89, 90+
    """
    logger.info("Computing age distributions")
    brackets = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, np.inf]
    return compute_distrib(df, "AGE", brackets)


def compute_year_distribution(df, max_year):
    """Compute the events year distribution for each endpoint"""
    logger.info("Computing year distributions")
    year_limit = max_year + 1  # the limit will be excluded, so we increment max_year to include it
    brackets = [np.NINF, 1970, 1975, 1980, 1985, 1990, 1995, 2000, 2005, 2010, 2015, year_limit]
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
    - pd.DataFrame
    """
    grouped = (
        df
        .groupby(["ENDPOINT", "FINNGENID"])
        .first()
    )
    sex_all = (
        grouped
        [column]
        .groupby("ENDPOINT")
        # Perform binning for each row, then count how many occurences for each bin
        .apply(lambda grp: green_hist(grp, brackets))
    )

    sex_female = (
        grouped
        .loc[grouped.sex == "female", column]
        .groupby("ENDPOINT")
        .apply(lambda grp: green_hist(grp, brackets))
    )

    sex_male = (
        grouped
        .loc[grouped.sex == "male", column]
        .groupby("ENDPOINT")
        .apply(lambda grp: green_hist(grp, brackets))
    )

    # Reshape dataframe
    data_df = []
    sex_data = [
        ("all", sex_all),
        ("female", sex_female),
        ("male", sex_male)
    ]
    for sex, df_sex in sex_data:
        for endpoint, bins in df_sex.items():
            for bin in bins:
                data_df.append([
                    endpoint,
                    sex,
                    bin["left"],
                    bin["right"],
                    bin["count"]
                ])

    return pd.DataFrame(
        data=data_df,
        columns=[
            "endpoint",
            "sex",
            "interval_left",
            "interval_right",
            "count"
        ]
    )

def green_hist(grp, brackets):
    """Merge histogram bins so that all bins are green data"""
    # Use pandas to pre-compute an histogram around fixed brackets
    hist = (
        pd.cut(grp, brackets, right=False)
        .value_counts()
        .sort_index()
    )

    res = []

    # Early return if count is too low to produce non individual-level data
    if hist.sum() not in INDIV_LEVELS:
        # Keep track of our rolling bin lower bound and count
        interval_left = None
        acc_count = 0

        for interval, count in hist.items():
            acc_count += count
            if interval_left is None:
                interval_left = interval.left

            if acc_count not in INDIV_LEVELS:
                res.append({
                    "left": interval_left,
                    "right": interval.right,
                    "count": acc_count
                })
                acc_count = 0
                interval_left = None

        # Last element was discarded in the loop if its count was in {1, 2, 3, 4}.
        # We need it to add to the result output.
        if acc_count in INDIV_LEVELS:
            res[-1]["count"] += acc_count
            res[-1]["right"] = interval.right

            # If the last count was added to bin with count of 0, then
            # we need to accumulate the value until it reaches a large
            # enough count.
            while res[-1]["count"] in INDIV_LEVELS:
                last = res.pop()
                res[-1]["count"] += last["count"]
                res[-1]["right"] = last["right"]

    assert all(map(lambda elem: elem["count"] not in INDIV_LEVELS, res))
    return res


def filter_stats(stats):
    """Remove individual-level data in the statistics"""
    logger.info("Filtering out individual level data in the statistics")

    # sex: all
    stats.loc[
        stats.loc[:, "nindivs_all"].isin(INDIV_LEVELS),
        ALL_COLS + FEMALE_COLS + MALE_COLS
    ] = None

    # sex: female
    stats.loc[
        stats.loc[:, "nindivs_female"].isin(INDIV_LEVELS),
        FEMALE_COLS
    ] = None

    # sex: male
    stats.loc[
        stats.loc[:, "nindivs_male"].isin(INDIV_LEVELS),
        MALE_COLS
    ] = None


def check_distrib_green(distrib):
    """Check there is no individual-level data in the given distribution bins"""
    logger.info("Checking for individual-level data in a distribution")
    error_msg = "Found some individual-level data, aborting"
    assert (~ distrib.loc[:, "count"].isin(INDIV_LEVELS)).all(), error_msg


def dict_distrib(distrib):
    """Transform distributions from a DataFrame to a Python dict

    Arguments:
    - distrib: pd.DataFrame
      Contains the data that will be turned into a dict.
      Must have columns:
      . 'sex' with values in 'all', 'male', 'female'
      . 'interval_left'
      . 'interval_right'
      . 'count'

    Return:
    - dict
      {"endpoint1": {
        "all": [
          [
            # Note that 10.0 is in this interval, but values > 10.0
            # (e.g. 10.1) will be in the [10, 20] interval
            [0, 10],  # [left, right] interval.
            12
          ], [[10, 20], 101] ...]},
        "female": ...},
       "endpoint 2": ...}
    """
    res = defaultdict(dict)

    # Some JSON implementations don't support NaN, so this will use null.
    # Use null to mark unbounded intervals.
    distrib = distrib.replace({np.nan: None, np.NINF: None, np.PINF: None})

    for (endpoint, df) in distrib.groupby("endpoint"):
        endpoint_dist = {"all": [], "female": [], "male": []}

        # Sort bin by interval, putting left unbounded interval as the first bin
        df = df.sort_values("interval_left", na_position="first")

        for _, row in df.iterrows():
            bin = [
                [row.interval_left, row.interval_right],
                row["count"]  # can't use row.count because it references the count method
            ]
            endpoint_dist[row.sex].append(bin)

        res[endpoint] = endpoint_dist

    return res


if __name__ == '__main__':
    main()
