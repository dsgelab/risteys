#!/usr/bin/env python3
"""
Do survival analysis (Cox hazard ratios) on endpoint pairs.

Usage
-----
Due to the expensive computations required, this script is usually run
using the dsub [1] piece of software.

However, this script can also be run in a standard python
environment. One needs to set the following environment variables (see
"Input files" and "Output files" sections for a description):
- INPUT_PAIRS
- INPUT_DEFINITIONS
- INPUT_DENSE_FEVENTS
- INPUT_INFO
- OUTPUT
- TIMINGS
and run:
  python surv_analysis.py

Input files
-----------
- INPUT_PAIRS
  CSV file containing a list of pairs to do survival analysis of.
  This file header is: prior,later
  Source: previous pipeline step

- INPUT_DEFINITIONS
  Endpoint definitions for FinnGen.
  Source: FinnGen

- INPUT_DENSE_FEVENTS
  The densified first-event phenotype file.
  Source: previous pipeline step

- INPUT_INFO
  Minimum information file.
  Each row is an individual, each column is a piece of information
  such as sex or age at baseline.
  Source: FinnGen

Output files
------------
- OUTPUT
  Result file, as CSV, one line per endpoint pair, with Cox HRs.
- TIMINGS
  File with how much time it took for each survival analysis.

Description
-----------
Do Cox regressions on the provided endpoint pairs. Each regression
will return metrics of interest, such as hazard ratio and p-value.


References
----------
[1] https://github.com/DataBiosphere/dsub/
[ ] CASE-COHORT
    https://www.stata.com/meeting/nordic-and-baltic16/slides/norway16_johansson.pdf
[ ] NB COMO
    https://plana-ripoll.github.io/NB-COMO/
"""
import logging
from csv import writer as csv_writer
from os import getenv
from pathlib import Path
from queue import LifoQueue
from time import time as now

import numpy as np
import pandas as pd
from lifelines import CoxPHFitter
from lifelines.utils import ConvergenceError
from lifelines.utils import interpolate_at_times

# TODO #
# Copy-pasted the logging configuration here instead of importing it
# from log.py.
# This is because dsub will run this script in a Docker image without
# having access to the log.py file.  There might be a solution to do
# this, for example by adding the log.py to the Docker image and
# moving it to the right place afterward.
level = getenv("LOG_LEVEL", logging.INFO)
logger = logging.getLogger("pipeline")
handler = logging.StreamHandler()
formatter = logging.Formatter(
    "%(asctime)s %(levelname)-8s %(module)-21s %(funcName)-25s: %(message)s")

handler.setFormatter(formatter)
logger.addHandler(handler)
logger.setLevel(level)
# END #


STUDY_STARTS = 1998.0  # inclusive
STUDY_ENDS = 2021.99   # inclusive, using same number format as FinnGen data files

N_SUBCOHORT = 10_000

# Minimum number of individuals having both the endpoint and died,
# this must be > 5 to not be deemed as containing individual-level data.
MIN_INDIVS = 10  # inclusive

class NotEnoughIndividuals(Exception):
    pass


# Step size for the fitting algorithm of CoxPHFitter
DEFAULT_STEP_SIZE = 1.0
LOWER_STEP_SIZE   = 0.1


# Lag durations (in years)
# Order (low-to-high) is important for performance later on, since if
# an endpoint pair doesn't have enough individuals for a duration then
# lower durations can be discarded directly.
# Since jobs are kept in a Last-In-First-Out (LIFO) queue, then we
# need to order them low-to-high in order for the jobs to run the
# longer durations first.
LAGS = [
    [0, 1],
    [1, 5],
    [5, 15],
    None
]


# Used for computing the absolute risk
MEAN_INDIV_BIRTH_YEAR = 1959.0
MEAN_INDIV_HAS_PRIOR_ENDPOINT = True
MEAN_INDIV_FEMALE_RATIO = 0.5
# Used for HR re-computation
BCH_TIMEPOINTS = [0, 2.5, 5, 7.5, 10, 12.5, 15, 17.5, 20, 21.99]


def main(path_pairs, path_definitions, path_dense_fevents, path_info, output_path, timings_path):
    # Initialize the CSV output
    line_buffering = 1
    res_file = open(output_path, "x", buffering=line_buffering)
    res_writer = init_csv(res_file)

    # File that keep tracks of how much time was spent on each endpoint
    timings_file = open(timings_path, "x", buffering=line_buffering)
    timings_writer = csv_writer(timings_file)
    timings_writer.writerow(["prior", "outcome", "lag", "step_size", "time_seconds"])

    # Load all data
    pairs, endpoints, df_events, df_info = load_data(
        path_pairs,
        path_definitions,
        path_dense_fevents,
        path_info
    )

    # Initialize the job queue
    jobs = LifoQueue()
    for pair in pairs:
        for lag in LAGS:
            jobs.put({"pair": pair, "lag": lag, "step_size": DEFAULT_STEP_SIZE})

    # Keep track if the current endpoint pair needs to be skipped
    skip = None

    # Run the regression for each job
    while not jobs.empty():
        time_start = now()

        # Get job info
        job = jobs.get()
        pair = job["pair"]
        lag = job["lag"]
        step_size = job["step_size"]

        # Go to next endpoint pair if this one is to be skipped
        if pair == skip:
            continue

        logger.info(f"Jobs remaining: ~ {jobs.qsize()}")
        logger.info(f"[JOB] pair: {pair} | lag: {lag} | step size: {step_size}")
        prior, outcome = pair
        is_sex_specific = pd.notna(endpoints.loc[endpoints.NAME == outcome, "SEX"].iloc[0])

        time_start = now()
        try:
            (df_unexp,
             df_unexp_death,
             df_unexp_exp_p1,
             df_unexp_exp_p2,
             df_tri_p1,
             df_tri_p2) = prep_coxhr(pair, lag, df_events, df_info)

            nindivs, df_lifelines = prep_lifelines(
                df_unexp,
                df_unexp_death,
                df_unexp_exp_p1,
                df_unexp_exp_p2,
                df_tri_p1,
                df_tri_p2
            )
            compute_coxhr(
                pair,
                df_lifelines,
                lag,
                step_size,
                is_sex_specific,
                nindivs,
                res_writer
            )
        except NotEnoughIndividuals as exc:
            skip = pair  # skip remaining jobs (different lags) for this endpoint pair
            logger.warning(exc)
        except (ConvergenceError, Warning) as exc:
            # Retry with a lower step_size
            if step_size == DEFAULT_STEP_SIZE:
                step_size = LOWER_STEP_SIZE
                jobs.put({"pair": pair, "lag": lag, "step_size": step_size})
            # We already tried with the lower step size, we have to skip this job
            else:
                logger.warning(f"Failed to run Cox.fit() for {pair}, lag: {lag}, step size: {step_size}:\n{exc}")
        finally:
            job_time = now() - time_start
            timings_writer.writerow([prior, outcome, lag, step_size, job_time])

    timings_file.close()
    res_file.close()


def load_data(path_pairs, path_definitions, path_dense_fevents, path_info):
    logger.info("Loading data")
    # Get pairs
    pairs = pd.read_csv(path_pairs)
    pairs = [(prior, outcome) for (prior, outcome) in pairs.to_numpy()]  # from DataFrame to Numpy array to tuple-list

    # Get endpoint list
    endpoints = pd.read_csv(path_definitions, usecols=["NAME", "SEX"])

    # Get first events
    df_events = pd.read_parquet(path_dense_fevents)

    # Get sex and approximate birth date of each indiv
    df_info = pd.read_csv(path_info, usecols=["FINNGENID", "BL_YEAR", "BL_AGE", "SEX"])
    df_info["female"] = df_info.SEX == "female"
    df_info = df_info.loc[(~ df_info.BL_YEAR.isna()) & (~ df_info.BL_AGE.isna()), :]  # remove individuals without time info
    df_info["BIRTH_TYEAR"] = df_info.BL_YEAR - df_info.BL_AGE
    df_info = df_info.drop(columns=["SEX", "BL_YEAR", "BL_AGE"])

    # Set age at start of study for each indiv.
    df_info["START_AGE"] = df_info.apply(
        lambda r: max(STUDY_STARTS - r.BIRTH_TYEAR, 0.0),
        axis="columns"
    )
    # We cannot set age at end of study yet, since it depends on the outcome age.
    # However, we need the death age for it when we are there.
    deaths = (
        df_events.loc[df_events.ENDPOINT == "DEATH", ["FINNGENID", "AGE"]]
        .rename(columns={"AGE": "DEATH_AGE"})
    )
    df_info = df_info.merge(deaths, on="FINNGENID", how="left")

    # Remove individuals that lived outside of the study time frame
    died_before_study = set(
        df_info.loc[
            df_info.DEATH_AGE < df_info.START_AGE,
            "FINNGENID"
        ].unique())
    df_events = df_events.loc[~ df_events.FINNGENID.isin(died_before_study), :]
    df_info = df_info.loc[~ df_info.FINNGENID.isin(died_before_study), :]

    born_after_study = set((df_info.BIRTH_TYEAR > STUDY_ENDS).index)
    df_events = df_events.loc[~ df_events.FINNGENID.isin(born_after_study), :]
    df_info = df_info.loc[~ df_info.FINNGENID.isin(born_after_study), :]

    return pairs, endpoints, df_events, df_info


def init_csv(res_file):
    res_writer = csv_writer(res_file)
    res_writer.writerow([
        "prior",
        "outcome",
        "lag_hr",
        "step_size",
        "nindivs_prior_outcome",
        "absolute_risk",
        "prior_coef",
        "prior_se",
        "prior_hr",
        "prior_ci_lower",
        "prior_ci_upper",
        "prior_pval",
        "prior_zval",
        "prior_norm_mean",
        "year_coef",
        "year_se",
        "year_hr",
        "year_ci_lower",
        "year_ci_upper",
        "year_pval",
        "year_zval",
        "year_norm_mean",
        "sex_coef",
        "sex_se",
        "sex_hr",
        "sex_ci_lower",
        "sex_ci_upper",
        "sex_pval",
        "sex_zval",
        "sex_norm_mean",
        # bch: baseline cumulative hazard
        "bch",
        "bch_0",
        "bch_2.5",
        "bch_5",
        "bch_7.5",
        "bch_10",
        "bch_12.5",
        "bch_15",
        "bch_17.5",
        "bch_20",
        "bch_21.99"
    ])

    return res_writer


def prep_coxhr(pair, lag, df_events, df_info):
    """Prepare the data to be used in the Cox model.

    Example timeline for an individual:

    study starts   prior  outcome     study ends
    |              |      |           |
    |--------------=======XXXXXXXXXXXX|
    [  unexposed  ][     exposed      ]
    """
    logger.info(f"Preparing data before Cox fitting for {pair}")
    prior, outcome = pair

    # Remove prevalent cases: outcome before study starts
    logger.debug("Removing prevalent cases")
    prevalent = df_events.copy()
    prevalent = prevalent.loc[df_events.ENDPOINT == outcome, ["FINNGENID", "AGE"]]
    prevalent = prevalent.merge(df_info.loc[:, ["FINNGENID", "BIRTH_TYEAR"]], on="FINNGENID")
    prevalent = set(prevalent.loc[prevalent.BIRTH_TYEAR + prevalent.AGE < STUDY_STARTS, "FINNGENID"])

    df_events = df_events.loc[~ df_events.FINNGENID.isin(prevalent), :]
    df_info = df_info.loc[~ df_info.FINNGENID.isin(prevalent), :]

    # Define groups for the case-cohort design study.
    # Naming follows Johansson-16 paper.
    logger.debug("Setting-up the case-cohort design study")
    cohort = set(df_events.FINNGENID)
    cases = set(df_events.loc[df_events.ENDPOINT == outcome, "FINNGENID"])
    size = min(N_SUBCOHORT, len(cohort))
    cc_subcohort = set(np.random.choice(list(cohort), size, replace=False))
    cc_m = len(cohort - cases)
    cc_ms = len(cc_subcohort & (cohort - cases))
    cc_pm = cc_ms / cc_m
    cc_weight_non_cases = 1 / cc_pm
    cc_sample = cases | cc_subcohort

    # Reduce the original population to be the smaller "sample" pop from the case-cohort study
    df_events = df_events.loc[df_events.FINNGENID.isin(cc_sample), :]
    df_info = df_info.loc[df_info.FINNGENID.isin(cc_sample), :]

    # Assign case-cohort weight to each individual
    df_weights = pd.DataFrame({"FINNGENID": list(cc_sample)})
    df_weights["weight"] = 1.0
    df_weights.loc[~ df_weights.FINNGENID.isin(cases), "weight"] = cc_weight_non_cases
    df_info = df_info.merge(df_weights, on="FINNGENID")

    # Individuals with prior: exclude those when prior age > outcome age
    logger.debug("Taking care of individuals with prior age > outcome age")
    prior_age = df_events.loc[df_events.ENDPOINT == prior, ["FINNGENID", "AGE"]].rename(columns={"AGE": "prior"})
    outcome_age = df_events.loc[df_events.ENDPOINT == outcome, ["FINNGENID", "AGE"]].rename(columns={"AGE": "outcome"})
    ages = prior_age.merge(outcome_age, how="inner")  # keep those that have prior + outcome
    exclude = set(ages.loc[ages.prior > ages.outcome, "FINNGENID"])

    # Define groups for the unexposed/exposed study
    logger.debug("Setting-up unexposed/exposed")
    with_prior = set(df_events.loc[df_events.ENDPOINT == prior, "FINNGENID"])
    with_prior = with_prior - exclude
    unexp             = cohort - with_prior - cases
    unexp_outcome     = cases - with_prior
    unexp_exp         = with_prior - cases
    unexp_exp_outcome = with_prior & cases
    assert len(cohort) == len(unexp) + len(unexp_outcome) + len(unexp_exp) + len(unexp_exp_outcome)

    # Check that we have enough individuals to do the study
    nindivs = len(unexp_exp_outcome)
    if nindivs < MIN_INDIVS:
        raise NotEnoughIndividuals(f"Not enough individuals having {prior} -> {outcome}: {nindivs} < {MIN_INDIVS}")
    elif len(unexp_exp) < MIN_INDIVS:
        raise NotEnoughIndividuals(f"Not enougth individuals in group: {prior} + no {outcome}, {len(unexp_exp)} < {MIN_INDIVS}")

    # Build main DataFrame with necessary info (1 line = 1 individual)
    logger.debug("Setting prior, outcome and end ages")
    # PRIOR_AGE
    df_prior = (
        df_events.loc[df_events.ENDPOINT == prior, ["FINNGENID", "AGE"]]
        .rename(columns={"AGE": "PRIOR_AGE"})
    )
    df_sample = df_info.merge(df_prior, on="FINNGENID", how="left")  # left join to keep individuals not having the endpoint
    # OUTCOME_AGE
    df_outcome = (
        df_events.loc[df_events.ENDPOINT == outcome, ["FINNGENID", "AGE"]]
        .rename(columns={"AGE": "OUTCOME_AGE"})
    )
    # END_AGE
    df_sample = df_sample.merge(df_outcome, on="FINNGENID", how="left")
    df_sample["END_AGE"] = pd.DataFrame({
        "outcome": df_sample.OUTCOME_AGE,
        "death": df_sample.DEATH_AGE,
        "study_ends": STUDY_ENDS - df_sample.BIRTH_TYEAR,
    }).min(axis="columns")

    # Move endpoint to study start if it happened before the study
    exposed_before_study = df_sample.PRIOR_AGE < df_sample.START_AGE
    df_sample.loc[exposed_before_study, "PRIOR_AGE"] = df_sample.loc[exposed_before_study, "START_AGE"]

    logger.info("Building timeline DataFrames with controls, unexposed, exposed")
    # Controls
    df_unexp = df_sample.loc[df_sample.FINNGENID.isin(unexp), :].copy()
    df_unexp["duration"] = df_unexp.END_AGE - df_unexp.START_AGE
    df_unexp["prior"] = False
    df_unexp["outcome"] = False

    # Unexposed -> Outcome
    df_unexp_outcome = df_sample.loc[df_sample.FINNGENID.isin(unexp_outcome), :].copy()
    df_unexp_outcome["duration"] = df_unexp_outcome.OUTCOME_AGE - df_unexp_outcome.START_AGE
    df_unexp_outcome["prior"] = False
    df_unexp_outcome["outcome"] = True

    # Unexposed -> Exposed: need time-window splitting
    df_unexp_exp = df_sample.loc[df_sample.FINNGENID.isin(unexp_exp), :].copy()
    # Phase 1: unexposed
    df_unexp_exp_p1 = df_unexp_exp.copy()
    df_unexp_exp_p1["duration"] = df_unexp_exp_p1.PRIOR_AGE - df_unexp_exp_p1.START_AGE
    df_unexp_exp_p1["prior"] = False
    df_unexp_exp_p1["outcome"] = False
    # Phase 2: exposed
    df_unexp_exp_p2 = df_unexp_exp.copy()
    df_unexp_exp_p2["prior"] = True
    if lag is None:  # no lag HR
        duration = df_unexp_exp_p2.END_AGE - df_unexp_exp_p2.PRIOR_AGE
    else:
        # Duration of exposure is time from exposure to "end" (death, study stop).
        # This current cohort (unexposed->exposed) has no one with an
        # outcome endpoint, so we don't need to do look ahead for an
        # outcome in a given lag time-window.
        # The lag is still used to cut the exposure time.
        _min_lag, max_lag = lag
        duration = df_unexp_exp_p2.apply(
            lambda r: min(r.END_AGE - r.PRIOR_AGE, max_lag),
            axis="columns"
        )
    df_unexp_exp_p2["duration"] = duration
    df_unexp_exp_p2["outcome"] = False

    # Unexposed -> Exposed -> Outcome: need time-window splitting
    df_tri = df_sample.loc[df_sample.FINNGENID.isin(unexp_exp_outcome), :].copy()
    # Phase 1: unexposed
    df_tri_p1 = df_tri.copy()
    df_tri_p1["duration"] = df_tri_p1.PRIOR_AGE - df_tri_p1.START_AGE
    df_tri_p1["prior"] = False
    df_tri_p1["outcome"] = False
    # Phase 2: exposed
    df_tri_p2 = df_tri.copy()
    df_tri_p2["prior"] = True
    if lag is None:
        duration = df_tri_p2.END_AGE - df_tri.PRIOR_AGE
        outcome = True
    else:
        min_lag, max_lag = lag
        # Duration is time from exposure endpoint to end event, no
        # matter of the lag time-window.
        duration = df_tri_p2.apply(
            lambda r: min(r.END_AGE - r.PRIOR_AGE, max_lag),
            axis="columns"
        )
        outcome_time = df_tri_p2.OUTCOME_AGE - df_tri_p2.PRIOR_AGE
        outcome = (outcome_time >= min_lag) & (outcome_time <= max_lag)
    df_tri_p2["duration"] = duration
    df_tri_p2["outcome"] = outcome

    return (
        df_unexp,
        df_unexp_outcome,
        df_unexp_exp_p1,
        df_unexp_exp_p2,
        df_tri_p1,
        df_tri_p2
    )


def prep_lifelines(df_unexp, df_unexp_death, df_unexp_exp_p1, df_unexp_exp_p2, df_tri_p1, df_tri_p2):
    logger.info("Preparing lifelines dataframes")

    # Re-check that there are enough individuals to do the study,
    # since after setting the lag some individuals might not have the
    # death outcome anymore.
    nindivs, _ =  df_tri_p2.loc[df_tri_p2.prior & df_tri_p2.outcome, :].shape
    if nindivs < MIN_INDIVS:
        raise NotEnoughIndividuals(f"not enough individuals with lag")

    # Concatenate the data frames together
    keep_cols = ["duration", "prior", "BIRTH_TYEAR", "female", "outcome", "weight"]
    df_lifelines = pd.concat([
        df_unexp.loc[:, keep_cols],
        df_unexp_death.loc[:, keep_cols],
        df_unexp_exp_p1.loc[:, keep_cols],
        df_unexp_exp_p2.loc[:, keep_cols],
        df_tri_p1.loc[:, keep_cols],
        df_tri_p2.loc[:, keep_cols]],
        ignore_index=True)

    return nindivs, df_lifelines


def compute_coxhr(pair, df, lag, step_size, is_sex_specific, nindivs, res_writer):
    logger.info(f"Running Cox regression")
    prior, outcome = pair
    # Handle sex-specific endpoints
    if is_sex_specific:
        df = df.drop(columns=["female"])

    # Fit Cox model
    cph = CoxPHFitter()
    cph.fit(
        df,
        duration_col="duration",
        event_col="outcome",
        step_size=step_size,
        # For the case-cohort study we need weights and robust errors:
        weights_col="weight",
        robust=True
    )

    # Compute absolute risk
    mean_indiv = pd.DataFrame({
        "BIRTH_TYEAR": [MEAN_INDIV_BIRTH_YEAR],
        "prior": [MEAN_INDIV_HAS_PRIOR_ENDPOINT],
        "female": [MEAN_INDIV_FEMALE_RATIO]
    })
    if is_sex_specific:
        mean_indiv.pop("female")

    if lag is None:
        predict_at = STUDY_ENDS - STUDY_STARTS
        lag_value = None
    else:
        _min_lag, max_lag = lag
        predict_at = max_lag
        lag_value = max_lag

    surv_probability = cph.predict_survival_function(
        mean_indiv,
        times=[predict_at]
    ).values[0][0]
    absolute_risk = 1 - surv_probability

    # Get values out of the fitted model
    norm_mean = cph._norm_mean
    prior_coef = cph.params_["prior"]
    prior_se = cph.standard_errors_["prior"]
    prior_hr = np.exp(prior_coef)
    prior_ci_lower = np.exp(prior_coef - 1.96 * prior_se)
    prior_ci_upper = np.exp(prior_coef + 1.96 * prior_se)
    prior_pval = cph.summary.p["prior"]
    prior_zval = cph.summary.z["prior"]
    prior_norm_mean = norm_mean["prior"]

    year_coef = cph.params_["BIRTH_TYEAR"]
    year_se = cph.standard_errors_["BIRTH_TYEAR"]
    year_hr = np.exp(year_coef)
    year_ci_lower = np.exp(year_coef - 1.96 * year_se)
    year_ci_upper = np.exp(year_coef + 1.96 * year_se)
    year_pval = cph.summary.p["BIRTH_TYEAR"]
    year_zval = cph.summary.z["BIRTH_TYEAR"]
    year_norm_mean = norm_mean["BIRTH_TYEAR"]

    if not is_sex_specific:
        sex_coef = cph.params_["female"]
        sex_se = cph.standard_errors_["female"]
        sex_hr = np.exp(sex_coef)
        sex_ci_lower = np.exp(sex_coef - 1.96 * sex_se)
        sex_ci_upper = np.exp(sex_coef + 1.96 * sex_se)
        sex_pval = cph.summary.p["female"]
        sex_zval = cph.summary.z["female"]
        sex_norm_mean = norm_mean["female"]
    else:
        sex_coef = np.nan
        sex_se = np.nan
        sex_hr = np.nan
        sex_ci_lower = np.nan
        sex_ci_upper = np.nan
        sex_pval = np.nan
        sex_zval = np.nan
        sex_norm_mean = np.nan

    # Save the baseline cumulative hazard (bch)
    df_bch = cph.baseline_cumulative_hazard_

    baseline_cumulative_hazard = bch_at(df_bch, predict_at)

    bch_values = {}
    for time in BCH_TIMEPOINTS:
        bch_values[time] = bch_at(df_bch, time)

    # Save values
    res_writer.writerow([
        prior,
        outcome,
        lag_value,
        step_size,
        nindivs,
        absolute_risk,
        prior_coef,
        prior_se,
        prior_hr,
        prior_ci_lower,
        prior_ci_upper,
        prior_pval,
        prior_zval,
        prior_norm_mean,
        year_coef,
        year_se,
        year_hr,
        year_ci_lower,
        year_ci_upper,
        year_pval,
        year_zval,
        year_norm_mean,
        sex_coef,
        sex_se,
        sex_hr,
        sex_ci_lower,
        sex_ci_upper,
        sex_pval,
        sex_zval,
        sex_norm_mean,
        baseline_cumulative_hazard,
        bch_values[0],
        bch_values[2.5],
        bch_values[5],
        bch_values[7.5],
        bch_values[10],
        bch_values[12.5],
        bch_values[15],
        bch_values[17.5],
        bch_values[20],
        bch_values[21.99]
    ])


def bch_at(df, time):
    try:
        res = df.loc[time, "baseline cumulative hazard"]
    except KeyError:
        # Index of the BCH dataframe are floats, which may not be exact values, so we check for the closest one
        res = interpolate_at_times(df, [time])[0]
    return res


if __name__ == '__main__':
    INPUT_PAIRS = Path(getenv("INPUT_PAIRS"))
    INPUT_DEFINITIONS = Path(getenv("INPUT_DEFINITIONS"))
    INPUT_DENSE_FEVENTS = Path(getenv("INPUT_DENSE_FEVENTS"))
    INPUT_INFO = Path(getenv("INPUT_INFO"))
    OUTPUT = Path(getenv("OUTPUT"))
    TIMINGS = Path(getenv("TIMINGS"))

    main(
        INPUT_PAIRS,
        INPUT_DEFINITIONS,
        INPUT_DENSE_FEVENTS,
        INPUT_INFO,
        OUTPUT,
        TIMINGS
    )
