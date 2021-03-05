"""
Compute cumulative incidence plots.
"""
import argparse
from pathlib import Path

import pandas as pd
from lifelines import CoxPHFitter

from log import logger


# -- CONFIGURATION
MIN_CASES = 100
STUDY_STARTS = 1998.0
MEAN_APPROX_BIRTH_DATE = 1959.39

PLOT_AGE_MIN = 0     # Inclusive
PLOT_AGE_MAX = 100   # Inclusive. Keep as much as possible, we can truncate later when plotting


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
    # TODO check if should cast to int
    df_minimum["approx_birth_date"] = df_minimum.BL_YEAR - df_minimum.BL_AGE

    # We assume we have the info for everyone and that it's either
    # "female" or "male".
    df_minimum["female"] = df_minimum.SEX == "female"
    df_minimum = df_minimum.loc[:, ["FINNGENID", "approx_birth_date", "female"]]

    return df_events, df_follow_up, df_minimum


def compute_cumulative_incidence(
        endpoint,
        is_sex_specific,
        df_events,
        df_follow_up,
        df_minimum
):
    """Compute the cumulative incidence for a given endpoint"""
    logger.info(f"Computing cumulative incidence for: {endpoint}")

    logger.debug("Assigning cases and controls")

    # Cases
    df_cases = df_events.loc[df_events.ENDPOINT == endpoint].copy()
    # Exclude prevalent cases
    df_cases = df_cases.loc[df_cases.ENDPOINT_YEAR >= STUDY_STARTS, :]
    df_cases["duration"] = df_cases.ENDPOINT_AGE
    df_cases["outcome"] = True

    # Controls
    df_controls = df_follow_up.loc[
        # Get only the non-cases
        ~ df_follow_up.FINNGENID.isin(df_cases.FINNGENID)
        , ["FINNGENID", "FU_END_AGE"]
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

    logger.debug("Fitting Cox model")

    # Fit Cox model
    mean_indiv = {
        "female": [0, 1],
        "approx_birth_date": [MEAN_APPROX_BIRTH_DATE, MEAN_APPROX_BIRTH_DATE]
    }
    if not is_sex_specific:
        formula = "female + approx_birth_date"
    else:
        formula = "approx_birth_date"
        mean_indiv.pop("female")

    cph = CoxPHFitter()
    cph.fit(dfcox, duration_col="duration", event_col="outcome", formula=formula)

    logger.debug("Using fitted model to derive cumulative incidence")

    # Derive cumulative incidence from model
    at_times = range(PLOT_AGE_MIN, PLOT_AGE_MAX + 1)  # include age max
    surv_prob = cph.predict_survival_function(
        pd.DataFrame(mean_indiv),
        times=at_times
    )
    cumulative_incidence = 1 - surv_prob
    cumulative_incidence = cumulative_incidence.rename(
        columns={0: "male", 1: "female"}
    )
    cumulative_incidence["age"] = cumulative_incidence.index

    return cumulative_incidence


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
    for _, row in endpoints.iterrows():
        endp = row.NAME
        is_sex_specific = row.SEX in ("1", "2")
        cumulative_incidence = compute_cumulative_incidence(
            endp,
            is_sex_specific,
            df_events,
            df_follow_up,
            df_minimum
        )
        cumulative_incidence["endpoint"] = endp

        # Output to a file
        filename = "cumulative-incidence_" + endp + ".csv"
        output_path = args.output / filename
        cumulative_incidence.to_csv(output_path, index=False)


if __name__ == '__main__':
    main()
