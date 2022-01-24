"""
Compute cumulative incidence plots.
"""
import argparse
import multiprocessing
from pathlib import Path

import numpy as np
import pandas as pd
from lifelines import CoxPHFitter

from log import logger


# -- CONFIGURATION
MIN_CASES = 100
N_MIN_INDIV = 5  # at least that many individuals to have for each data point in the output
MAX_TIME_POINTS = 100  # at most that many time points in the output


class NotEnoughCases(Exception):
    pass


def cli_parser():
    """Setup the command line argument parsing"""
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "-e", "--endpoint-definitions",
        help="path to the endpoint definitions file (CSV)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-d", "--dense-events",
        help="path to the dense events file (CSV)",
        required=True,
        type=Path
    )
    # File containing FINNGENID, FU_END_AGE and SEX (subset from endpoint first-event file)
    parser.add_argument(
        "-f", "--info",
        help="path to the file with follow-up end age and sex information (CSV)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-o", "--output",
        help="path to output directory with plot values for each endpoint (CSV)",
        required=True,
        type=Path
    )

    args = parser.parse_args()
    return args


def load_endpoints(file_path):
    """Load the CSV file with endpoints under the column NAME"""
    df = pd.read_csv(
        file_path,
        usecols=["NAME", "SEX"],
    )
    return df


def load_data(dense_events, info):
    logger.info("Loading data")
    df_events = pd.read_csv(
        dense_events,
        usecols=[
            "FINNGENID",
            "ENDPOINT",
            "AGE"
        ]
    ).rename(columns={
        "AGE": "ENDPOINT_AGE"
    })

    df_info = pd.read_csv(info)

    return df_events, df_info


def comp_cph(
        endpoint,
        sex,
        df_events,
        df_info
):
    """Prepare data and fit a Cox PH model for the given endpoint"""
    logger.info(f"{endpoint} - {sex} - Computing cumulative incidence")
    logger.debug(f"{endpoint} - {sex} - Assigning cases and controls")

    # Cases
    df_cases = df_events.loc[df_events.ENDPOINT == endpoint, ["FINNGENID", "ENDPOINT_AGE"]]
    if df_cases.shape[0] < MIN_CASES:
        raise NotEnoughCases(f"Not enough cases (< {MIN_CASES}).")

    # Take all individual, also dealing with sex-specific endpoints
    df_all = df_info.loc[df_info.SEX == sex, ["FINNGENID", "FU_END_AGE"]]

    df_all = df_all.merge(df_cases, how="left", on="FINNGENID")
    df_all["outcome"] = ~ df_all.ENDPOINT_AGE.isna()  # ENDPOINT_AGE is NaN for controls
    df_all["duration"] = df_all.FU_END_AGE
    df_all.loc[df_all.outcome, "duration"] = df_all.loc[df_all.outcome, "ENDPOINT_AGE"]

    # Trim down the columns so the later call to cph.fit() doesn't try to use extra columns
    dfcox = df_all.loc[:, ["outcome", "duration"]]

    logger.debug(f"{endpoint} - Fitting Cox model")
    cph = CoxPHFitter()
    cph.fit(dfcox, duration_col="duration", event_col="outcome")

    return dfcox, cph


def get_cumulative_incidence(dfcox, df_info, cph, sex):
    """Derive cumulative incidence from fitted CPH model"""
    logger.debug(f"Using fitted model to derive cumulative incidence")

    # Since the cumulative incidence will be outputted for females and
    # males separately, we need to take time points independently for
    # each. That way we make sure we have groups of N ≥ 5 for both the
    # female curve and the male curve.
    indivs = dfcox.loc[df_info.SEX == sex, :]
    at_times = find_time_points(indivs, N_MIN_INDIV, MAX_TIME_POINTS)
    res = cumulinc_at_times(cph, dfcox, at_times)
    res["sex"] = sex

    # Keep only a limited precision on float
    res.cumulinc = res.cumulinc.apply(lambda n: "{:06.4f}".format(n))

    return res


def cumulinc_at_times(cph, dfcox, at_times):
    """Generic way to compute the cumulative incidence at given time points"""
    surv_prob = cph.predict_survival_function(
        dfcox,
        times=at_times
    )
    cumulative_incidence = 1 - surv_prob

    # Compute the mean cumulative incidence for each age
    cumulative_incidence = cumulative_incidence.mean(axis="columns")

    df_out = cumulative_incidence.reset_index(name="cumulinc")
    df_out = df_out.rename(columns={"index": "age"})
    return df_out


def find_time_points(dfcox, n_min, max_time_points):
    """Find time points that make groups of `n_min` individuals minimum.

    This is useful for getting non-individual-level data, since we can
    make sure each data point covers at least 6 individuals.
    """
    time_points = []

    cases = dfcox.loc[dfcox.outcome, :].duration.sort_values()
    controls = dfcox.loc[~ dfcox.outcome, :].duration.sort_values()

    while cases.shape[0] >= n_min and controls.shape[0] >= n_min:
        idx_min = n_min - 1
        age_cases = cases.iloc[idx_min]
        age_controls = controls.iloc[idx_min]
        age = max(age_cases, age_controls)

        time_points.append(age)

        cases = cases.loc[cases > age]
        controls = controls.loc[controls > age]

    # Keep a given maximum number of time points if there are too many
    if len(time_points) > max_time_points:
        arr_time_points = np.array(time_points)
        last_idx = len(time_points) - 1
        keep_idx = np.linspace(0, last_idx, max_time_points).astype(np.int)
        time_points = arr_time_points[keep_idx]

    return time_points


def worker_job(endpoint, sex, df_events, df_info, output):
    try:
        dfcox, cph = comp_cph(
            endpoint,
            sex,
            df_events,
            df_info
        )
        cumulative_incidence = get_cumulative_incidence(dfcox, df_info, cph, sex)
    except Exception as exc:
        logger.warning(f"{endpoint} - unexpected error of type {type(exc)}")

        # Write detailed error to a file
        filename = f"cumulative-incidence_error_{endpoint}_{sex}.log"
        output_path = output / filename
        with open(output_path, "w") as fd:
            print(exc, file=fd)
    else:
        # Add column with endpoint name to resulting DataFrame
        cumulative_incidence["endpoint"] = endpoint

        # Output to a file
        filename = f"cumulative-incidence_{endpoint}_{sex}.csv"
        output_path = output / filename
        cumulative_incidence.to_csv(
            output_path,
            index=False,
            na_rep='nan'
        )

        logger.debug(f"{endpoint} - done")


def main():
    args = cli_parser()

    # Load endpoints
    endpoints = load_endpoints(args.endpoint_definitions)
    df_events, df_info = load_data(
        args.dense_events,
        args.info
    )

    # Compute cumulative incidences
    logger.info("Preparing tasks")
    tasks = []
    for _, row in endpoints.iterrows():
        endp = row.NAME

        male_args = (
            endp,
            "male",
            df_events,
            df_info,
            args.output
        )
        female_args = (
            endp,
            "female",
            df_events,
            df_info,
            args.output
        )

        if row.SEX == 1:
            tasks.append(male_args)
        elif row.SEX == 2:
            tasks.append(female_args)
        else:
            tasks.append(male_args)
            tasks.append(female_args)

    njobs = multiprocessing.cpu_count()
    with multiprocessing.Pool(njobs) as worker_pool:
        worker_pool.starmap(worker_job, tasks)


if __name__ == '__main__':
    main()
