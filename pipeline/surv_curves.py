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

STUDY_STARTS = 1998.0
MEAN_APPROX_BIRTH_DATE = 1959.39

N_MIN_INDIV = 6  # at least that many individuals to have for each data point in the output
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
    # Minimum file is used to compute approximate birth dates
    parser.add_argument(
        "-m", "--minimum",
        help="path to the FinnGen minimum phenotype file (CSV)",
        required=True,
        type=Path
    )
    # File containing FINNGENID and FU_END_AGE to get the follow-up end age
    parser.add_argument(
        "-f", "--follow-up",
        help="path to the file with follow-up end age information (CSV)",
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
        skiprows=[1]  # first row is a comment
    )
    return df


def load_data(dense_events, minimum, follow_up):
    logger.info("Loading data")
    df_events = pd.read_csv(
        dense_events,
        usecols=[
            "FINNGENID",
            "ENDPOINT",
            "AGE",
            "YEAR"
        ]
    ).rename(columns={
        "AGE": "ENDPOINT_AGE",
        "YEAR": "ENDPOINT_YEAR"
    })

    df_follow_up = pd.read_csv(follow_up)

    df_minimum = pd.read_csv(
        minimum,
        usecols=[
            "FINNGENID",
            # To change the model if the endpoint is sex specific:
            "SEX",
            # To compute approximate birth dates:
            "BL_YEAR",
            "BL_AGE"
        ]
    )

    # Compute approximate birth date
    df_minimum["approx_birth_date"] = df_minimum.BL_YEAR - df_minimum.BL_AGE

    # We assume we have the info for everyone and that it's either
    # "female" or "male".
    df_minimum["female"] = df_minimum.SEX == "female"
    df_minimum = df_minimum.loc[:, ["FINNGENID", "approx_birth_date", "female"]]

    return df_events, df_follow_up, df_minimum


def comp_cph(
        endpoint,
        sex,
        df_events,
        df_follow_up,
        df_minimum
):
    """Prepare data and fit a Cox PH model for the given endpoint"""
    logger.info(f"{endpoint} - Computing cumulative incidence")
    logger.debug(f"{endpoint} - Assigning cases and controls")

    # Cases
    df_cases = df_events.loc[df_events.ENDPOINT == endpoint].copy()
    # Exclude prevalent cases
    df_cases = df_cases.loc[df_cases.ENDPOINT_YEAR >= STUDY_STARTS, :]
    df_cases["duration"] = df_cases.ENDPOINT_AGE
    df_cases["outcome"] = True

    if df_cases.shape[0] < MIN_CASES:
        raise NotEnoughCases(f"Not enough cases (< {MIN_CASES}).")

    # Controls
    df_controls = df_follow_up.loc[
        # Get only the non-cases
        ~ df_follow_up.FINNGENID.isin(df_cases.FINNGENID),
        ["FINNGENID", "FU_END_AGE"]
    ].copy()
    df_controls["duration"] = df_controls.FU_END_AGE
    df_controls["outcome"] = False

    # Shape the dataframe for use in Cox model
    dfcox = pd.concat([df_cases, df_controls])
    dfcox = dfcox.merge(
        df_minimum,
        on="FINNGENID"
    )
    dfcox = dfcox.loc[:, ["duration", "outcome", "female", "approx_birth_date"]]

    logger.debug(f"{endpoint} - Fitting Cox model")

    # Prepare model for sex-specific endpoints
    if sex in ("female", "male"):
        formula = "approx_birth_date"
    else:
        formula = "female + approx_birth_date"

    # Fit Cox model
    cph = CoxPHFitter()
    cph.fit(dfcox, duration_col="duration", event_col="outcome", formula=formula)

    logger.debug(f"{endpoint} - Using fitted model to derive cumulative incidence")

    return dfcox, cph


def get_cumulative_incidence(dfcox, cph, sex):
    """Derive cumulative incidence from fitted CPH model"""
    mean_female_indiv = {
        "female": [1],
        "approx_birth_date": [MEAN_APPROX_BIRTH_DATE]
    }
    mean_male_indiv = {
        "female": [0],
        "approx_birth_date": [MEAN_APPROX_BIRTH_DATE]
    }

    if sex == "female":
        at_times = find_time_points(dfcox, N_MIN_INDIV, MAX_TIME_POINTS)
        res = cumulinc_at_times(cph, mean_female_indiv, at_times)
        res["sex"] = "female"

    elif sex == "male":
        at_times = find_time_points(dfcox, N_MIN_INDIV, MAX_TIME_POINTS)
        res = cumulinc_at_times(cph, mean_male_indiv, at_times)
        res["sex"] = "male"

    else:
        # Since the cumulative incidence will be outputted for females
        # and males separately, we need to take time points
        # independently for each. That way we make sure we have groups
        # of N > 5 for both the female curve and the male curve.
        females = dfcox.loc[dfcox.female, :]
        female_at_times = find_time_points(females, N_MIN_INDIV, MAX_TIME_POINTS)
        res_female = cumulinc_at_times(cph, mean_female_indiv, female_at_times)
        res_female["sex"] = "female"

        males = dfcox.loc[~dfcox.female, :]
        male_at_times = find_time_points(males, N_MIN_INDIV, MAX_TIME_POINTS)
        res_male = cumulinc_at_times(cph, mean_male_indiv, male_at_times)
        res_male["sex"] = "male"

        res = pd.concat([res_female, res_male])

    # Keep only a limited precision on float
    res.cumulinc = res.cumulinc.apply(lambda n: "{:06.4f}".format(n))

    return res


def cumulinc_at_times(cph, indiv, at_times):
    """Generic way to compute the cumulative incidence at given time points"""
    surv_prob = cph.predict_survival_function(
        pd.DataFrame(indiv),
        times=at_times
    )
    cumulative_incidence = 1 - surv_prob

    # Give a more meaningful name to cumulative incidence values
    cumulative_incidence = cumulative_incidence.rename(
        columns={0: "cumulinc"}
    )

    cumulative_incidence["age"] = cumulative_incidence.index

    # Order column so that all output files are consistent
    cumulative_incidence = cumulative_incidence.loc[:, ["age", "cumulinc"]]
    return cumulative_incidence


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


def worker_job(endpoint, sex, df_events, df_follow_up, df_minimum, output):
    try:
        dfcox, cph = comp_cph(
            endpoint,
            sex,
            df_events,
            df_follow_up,
            df_minimum
        )
        cumulative_incidence = get_cumulative_incidence(dfcox, cph, sex)
    except Exception as exc:
        logger.warning(f"{endpoint} - unexpected error of type {type(exc)}")

        # Write detailed error to a file
        filename = "cumulative-incidence_error_" + endpoint + ".log"
        output_path = output / filename
        with open(output_path, "w") as f:
            print(exc, file=f)
    else:
        # Add column with endpoint name to resulting DataFrame
        cumulative_incidence["endpoint"] = endpoint

        # Output to a file
        filename = "cumulative-incidence_" + endpoint + ".csv"
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
    df_events, df_follow_up, df_minimum = load_data(
        args.dense_events,
        args.minimum,
        args.follow_up
    )

    # Compute cumulative incidences
    logger.info("Preparing tasks")
    tasks = []
    for _, row in endpoints.iterrows():
        endp = row.NAME

        if row.SEX == 1:
            sex = "male"
        elif row.SEX == 2:
            sex = "female"
        else:
            sex = np.nan

        worker_args = (
            endp,
            sex,
            df_events,
            df_follow_up,
            df_minimum,
            args.output
        )
        tasks.append(worker_args)

    with multiprocessing.Pool(multiprocessing.cpu_count()) as worker_pool:
        worker_pool.starmap(worker_job, tasks)


if __name__ == '__main__':
    main()
