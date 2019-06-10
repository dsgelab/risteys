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
- stats.df5: HDF5 file with statistics and distributions for each endpoint
"""
from csv import excel_tab
from pathlib import Path
from sys import argv

import numpy as np
import pandas as pd

from log import logger


OUTPUT_FILENAME = "stats.hdf5"


def prechecks(longit_file, mindata_file):
    """Perform checks before running to fail earlier rather than later"""
    logger.info("Performing pre-checks")
    assert longit_file.exists(), f"{longit_file} doesn't exist"
    assert mindata_file.exists(), f"{mindata_file} doesn't exist"
    assert not OUTPUT_FILEPATH.exists(), f"{OUTPUT_FILEPATH} already exists, not overwritting it"
    assert not OUTPUT_RECOVERY.exists(), f"{OUTPUT_RECOVERY} already exists, not overwritting it"

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
    outdata.to_hdf(OUTPUT_RECOVERY, "/stats")

    outdata = compute_mean_age(indata, outdata)
    outdata.to_hdf(OUTPUT_RECOVERY, "/stats")

    outdata = compute_median_events(indata, outdata)
    outdata.to_hdf(OUTPUT_RECOVERY, "/stats")

    outdata = compute_reoccurence(indata, outdata)
    outdata.to_hdf(OUTPUT_RECOVERY, "/stats")

    outdata = compute_case_fatality(indata, outdata)
    outdata.to_hdf(OUTPUT_RECOVERY, "/stats")

    outdata = compute_age_distribution(indata)
    logger.debug("Writing age distribution to HDF5")
    outdata.to_hdf(OUTPUT_RECOVERY, "/distrib/age")

    outdata = compute_year_distribution(indata)
    logger.debug("Writing year distribution to HDF5")
    outdata.to_hdf(OUTPUT_RECOVERY, "/distrib/year")

    # Everything went fine, moving recovery file to proper output path
    OUTPUT_RECOVERY.rename(OUTPUT_FILEPATH)

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
    logger.info("Computing count by sex")
    count_by_sex = df.groupby("FINNGENID")
    count_by_sex = count_by_sex[["female", "male"]]
    count_by_sex = count_by_sex.first()
    count_female = count_by_sex["female"].sum()
    count_male = count_by_sex["male"].sum()
    count_all = count_female + count_male
    check_count_all = df["FINNGENID"].unique().size
    assert count_all == check_count_all, f"Counts for sex 'all' defer: {count_all} != {check_count_all}"

    # Un-adjusted prevalence
    logger.info("Computing un-adjusted prevalence")
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


def compute_mean_age(df, outdata):
    """Compute the mean age at first event for each endpoint"""
    logger.info("Computing mean age at first event")

    # sex: all
    stat = df.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat["EVENT_AGE"].min()
    stat = stat.groupby("ENDPOINT")
    stat = stat.mean()
    outdata["mean_age_all"] = stat

    # sex: female
    stat = df[df["female"] == 1]
    stat = stat.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat["EVENT_AGE"].min()
    stat = stat.groupby("ENDPOINT")
    stat = stat.mean()
    outdata["mean_age_female"] = stat

    # sex: male
    stat = df[df["male"] == 1]
    stat = stat.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat["EVENT_AGE"].min()
    stat = stat.groupby("ENDPOINT")
    stat = stat.mean()
    outdata["mean_age_male"] = stat

    return outdata


def compute_median_events(df, outdata):
    """Compute the median number of events by individual for each endpoint"""
    logger.info("Computing median number of events")

    # sex: all
    stat = df.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat["EVENT_YEAR"].count()  # could have selected any column as we just count events
    stat = stat.groupby("ENDPOINT")
    stat = stat.median()
    outdata["median_events_all"] = stat

    # sex: female
    stat = df[df["female"] == 1]
    stat = stat.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat["EVENT_YEAR"].count()
    stat = stat.groupby("ENDPOINT")
    stat = stat.median()
    outdata["median_events_female"] = stat

    # sex: male
    stat = df[df["male"] == 1]
    stat = stat.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat["EVENT_YEAR"].count()
    stat = stat.groupby("ENDPOINT")
    stat = stat.median()
    outdata["median_events_male"] = stat

    return outdata


def compute_reoccurence(df, outdata):
    """Compute the reoccurence rate within 6 months"""
    logger.info("Computing re-occurence within 6 months")
    window = 0.5  # in years, we assume the EVENT_AGE column is in years also

    # sex: all
    stat = df.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat["EVENT_AGE"].agg(lambda ages: any_reoccurence(ages, window))
    stat = stat.groupby("ENDPOINT")
    # For each endpoint, count the number of individuals with reoccurence / total individuals
    stat = stat.agg(lambda g: g[g == True].count() / g.count())
    outdata["reoccurence_all"] = stat

    # sex: female
    stat = df[df["female"] == 1]
    stat = stat.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat["EVENT_AGE"].agg(lambda ages: any_reoccurence(ages, window))
    stat = stat.groupby("ENDPOINT")
    stat = stat.agg(lambda g: g[g == True].count() / g.count())
    outdata["reoccurence_female"] = stat

    # sex: male
    stat = df[df["male"] == 1]
    stat = stat.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat["EVENT_AGE"].agg(lambda ages: any_reoccurence(ages, window))
    stat = stat.groupby("ENDPOINT")
    stat = stat.agg(lambda g: g[g == True].count() / g.count())
    outdata["reoccurence_male"] = stat

    return outdata


def any_reoccurence(events, window):
    """Check if any two events happened within a given time window

    NOTE: Performs a sort on the values since we don't assume they are already sorted.
    """
    events = events.sort_values()

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
    deaths = df.loc[df.loc[:, "ENDPOINT"] == "DEATH"]
    deaths = deaths.rename(columns={'EVENT_AGE': 'DEATH_AGE'})
    deaths = deaths.drop(["EVENT_YEAR", "ENDPOINT", "female", "male"], axis=1)
    # Individuals not dead are not in the "deaths" DataFrame so using
    # the default inner-join would remove all of them from the merged
    # DataFrame. We want to keep them so we use a left-join.
    logger.debug("Merging death event into DataFrame")
    df = df.merge(deaths, on="FINNGENID", how="left")

    logger.debug("Back to computing case fatality")
    # sex: all
    stat = df.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat["EVENT_AGE", "DEATH_AGE"].min()
    stat = stat["DEATH_AGE"] - stat["EVENT_AGE"] < window
    stat = stat.groupby("ENDPOINT").agg(lambda g: g[g == True].count() / g.count())
    outdata["case_fatality_all"] = stat

    # sex: female
    stat = df[df["female"] == 1]
    stat = stat.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat["EVENT_AGE", "DEATH_AGE"].min()
    stat = stat["DEATH_AGE"] - stat["EVENT_AGE"] < 5
    stat = stat.groupby("ENDPOINT").agg(lambda g: g[g == True].count() / g.count())
    outdata["case_fatality_female"] = stat

    # sex: male
    stat = df[df["male"] == 1]
    stat = stat.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat["EVENT_AGE", "DEATH_AGE"].min()
    stat = stat["DEATH_AGE"] - stat["EVENT_AGE"] < 5
    stat = stat.groupby("ENDPOINT").agg(lambda g: g[g == True].count() / g.count())
    outdata["case_fatality_male"] = stat

    return outdata


def compute_age_distribution(df):
    """Compute the age distribution of first event for each endpoint.

    Pre-defined age brackets:
    0-10, 11-20, 21-30, 31-40, 41-50, 51-60, 61-70, 71-80, 81-90, 91+
    """
    logger.info("Computing age distributions")
    brackets = [0, 11, 21, 31, 41, 51, 61, 71, 81, 91, np.inf]
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
    stat = df.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat[column].min()
    stat = stat.groupby("ENDPOINT")
    # Perform binning for each row, then count how many occurences for each bin
    stat = stat.apply(lambda g: pd.cut(g, brackets, right=False).value_counts())
    outdata["all"] = stat

    # sex: female
    stat = df[df["female"] == 1]
    stat = stat.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat[column].min()
    stat = stat.groupby("ENDPOINT")
    stat = stat.apply(lambda g: pd.cut(g, brackets, right=False).value_counts())
    outdata["female"] = stat

    # sex: male
    stat = df[df["male"] == 1]
    stat = stat.groupby(["ENDPOINT", "FINNGENID"])
    stat = stat[column].min()
    stat = stat.groupby("ENDPOINT")
    stat = stat.apply(lambda g: pd.cut(g, brackets, right=False).value_counts())
    outdata["male"] = stat

    return outdata


if __name__ == '__main__':
    # Get filenames from the command line arguments
    LONGIT_FILE = Path(argv[1])
    MINDATA_FILE = Path(argv[2])
    OUTPUT_DIR = Path(argv[3])

    OUTPUT_FILEPATH = OUTPUT_DIR / OUTPUT_FILENAME
    OUTPUT_RECOVERY = OUTPUT_FILEPATH.with_suffix(".hdf5.recovery")

    main(LONGIT_FILE, MINDATA_FILE)
