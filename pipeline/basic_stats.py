#!/usr/bin/env python3
"""
Aggregate data by endpoint on a couple of metrics, for female, male and all sex.

Output:
- stats.json: josn file with statistics and distributions for each endpoint, so it can be imported in a database afterwards.

"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import json
import datetime
from collections import defaultdict
# from log import logger

# data path
first_event_path = '/data/processed_data/endpointer/main/finngen_endpoints_04-09-2021_v3.densified_OMITs.txt'
info_path = '/data/notebooks/mpf/minimal_phenotype_file.csv'

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


def load_data(first_event_path, info_path):

    # load df for first event #

    df_fevent = pd.read_csv(first_event_path)
    df_fevent = df_fevent.astype({
        "FINNGENID": np.object,
        "ENDPOINT": np.object,
        "AGE": np.float64,
        "YEAR": np.int64,
        "NEVT": np.int64,
    })

    # load df for sex from minimal phenotype file #

    dfsex = pd.read_csv(info_path, usecols=["FINREGISTRYID", "sex"])
    # remove the only duplicate in the current version
    dfsex = dfsex.drop(4976996)
    # remove one line with NaN instead of an ID
    dfsex = dfsex[dfsex['FINREGISTRYID'].notna()]
    # remove all the null value in sex column
    dfsex = dfsex[dfsex.sex.notna()]

    dfsex = dfsex.astype({
        "FINREGISTRYID": np.object,
        "sex": "category",
    })

    # Perform one-hot encoding for SEX so it can be written to HDF without the slow format="table".
    onehot = pd.get_dummies(dfsex["sex"])
    dfsex = pd.concat([dfsex, onehot], axis=1)
    dfsex = dfsex.drop("sex", axis=1)

    # Add SEX information to DataFrame
    # NOTE: all the individuals (96028 in total) without sex info have been removed. 
    # After left join, we have 228186990 rows in df_fevent, 26 rows fewer than earlier.
    df_fevent = df_fevent.merge(dfsex, left_on="FINNGENID", right_on="FINREGISTRYID", how="left")
    del df_fevent['FINREGISTRYID']

    # Sort events for first-event data
    df_fevent = df_fevent.sort_values(by=["FINNGENID", "AGE"])
    df_fevent = df_fevent.reset_index(drop=True)

    df_fevent = df_fevent.rename(columns={1.0: "male", 2.0: "female"})

    return df_fevent

def compute_prevalence(df):
    """Compute the prevalence by endpoint for sex=all,female,male
    NOTE:
    The sex information is missing for some individual, so it cannot
    be assumed that females + males = all.
    """
    # Count total number of individuals by sex
#     logger.info("Computing count by sex")
    count_all = df.FINNGENID.unique().shape[0]
    count_female = df.loc[df.female > 0, "FINNGENID"].unique().shape[0]
    count_male = df.loc[df.male > 0, "FINNGENID"].unique().shape[0]

    # Number of individuals / endpoint for prevalence
#     logger.info("Computing un-adjusted prevalence")
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

    # create empty outdata
    outdata = pd.DataFrame()
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
#     logger.info("Computing mean age at first event")
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

def compute_age_distribution(df):
    """Compute the age distribution of first event for each endpoint.
    Pre-defined age brackets:
    0-9, 10-19, 20-29, 30-39, 40-49, 50-59, 60-69, 70-79, 80-89, 90+
    """
#     logger.info("Computing age distributions")
#     brackets = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 150]
    brackets = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, np.inf]
    return compute_distrib(df, "AGE", brackets)


def compute_year_distribution(df):
    """Compute the events year distribution for each endpoint"""
#     logger.info("Computing year distributions")
    # Get the latest year of events in the data
    max_year = df.YEAR.max()

    year_limit = max_year + 1  # the limit will be excluded, so we increment max_year to include it
#     brackets = [1900, 1970, 1975, 1980, 1985, 1990, 1995, 2000, 2005, 2010, 2015, year_limit]
    brackets = [-np.inf, 1970, 1975, 1980, 1985, 1990, 1995, 2000, 2005, 2010, 2015, np.inf]
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
    sex_all = (
        df
        .groupby(["ENDPOINT", "FINNGENID"])
        [column]
        .first()
        .groupby("ENDPOINT")
        # Perform binning for each row, then count how many occurences for each bin
        .apply(lambda grp: green_hist(grp, brackets))
    )

    sex_female = (
        df[df["female"] == 1]
        .groupby(["ENDPOINT", "FINNGENID"])
        [column]
        .first()
        .groupby("ENDPOINT")
        .apply(lambda grp: green_hist(grp, brackets))
    )

    sex_male = (
        df[df["male"] == 1]
        .groupby(["ENDPOINT", "FINNGENID"])
        [column]
        .first()
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
#     logger.info("Filtering out individual level data in the statistics")

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
#     logger.info("Checking for individual-level data in a distribution")
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

def main():
    start = datetime.datetime.now()

    # Load input data
    df_fevent = load_data(first_event_path, info_path)
    
    # Building up the aggregated statisitcs by endpoint
    stats = compute_prevalence(df_fevent)
    stats = compute_mean_age(df_fevent, stats)

    # Making the distributions by endpoint
    distrib_age = compute_age_distribution(df_fevent)
    # logger.debug("Writing age distribution to HDF5")

    distrib_year = compute_year_distribution(df_fevent)
    # logger.debug("Writing year distribution to HDF5")


    # Checking that we don't miss any column with individual-level data
    expected_columns = set(ALL_COLS + FEMALE_COLS + MALE_COLS)
    assert set(stats.columns) == set(expected_columns), f"Mismatch while checking that all columns with individual-level are covered: {set(expected_columns)} != {set(stats.columns)}"

    # Filtering the data to remove individual-level data
    filter_stats(stats)

    agg_stats = (stats.to_json(orient="index"))

    check_distrib_green(distrib_age)
    distrib_age = dict_distrib(distrib_age)
    distrib_age = json.dumps(distrib_age)

    check_distrib_green(distrib_year)
    distrib_year = dict_distrib(distrib_year)
    distrib_year = json.dumps(distrib_year)

    # Manually craft the JSON output given the 3 JSON strings we already have
    # logger.info(f"Writing out data to JSON in file {output_path}")
    output = f'{{"stats": {agg_stats}, "distrib_age": {distrib_age}, "distrib_year": {distrib_year}}}'
    # format date
    today = datetime.datetime.today().strftime("%Y-%m-%d")
    with open('finregistry_stats__'+today+'.json', "x") as f:
        f.write(output)

    end = datetime.datetime.now()
    print("Done. The time it took is "+str(end-start))

if __name__ == '__main__':
    main()
