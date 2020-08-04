### TODO ###
# - discard DEATH endpoint, or maybe do it in surv_endpoints.py
# - handle the special timeline cases now that outcome is not death (ex: prior > outcome)


from csv import writer as csv_writer
from pathlib import Path
from queue import LifoQueue
from sys import argv

import numpy as np
import pandas as pd
from lifelines import CoxPHFitter
from lifelines.utils import ConvergenceError

from log import logger


STUDY_STARTS = 1998.0  # inclusive
STUDY_ENDS = 2019.99   # inclusive, using same number format as FinnGen data files

N_SUBCOHORT = 10_000

# Minimum number of individuals having both the endpoint and died,
# this must be > 5 to not be deemed as containing individual-level data.
MIN_INDIVS = 10  # inclusive

class NotEnoughIndividuals(Exception):
    pass


DEFAULT_STEP_SIZE = 1.0
LOWER_STEP_SIZE   = 0.1


# Lag durations (in years)
# Order (low-to-high) is important for performance later on, since
# if an endpoint pair doesn't have enough individual for a duration
# then lower-duration can be discarded directly.
# Since jobs are kept in a Last-In-First-Out (LIFO) queue, then we
# need to order them low-to-high in order for the jobs to run the
# longer durations first.
LAGS = [1, 5, 15, None]


def main(path_pairs, path_definitions, path_dense_fevents, path_info, output_path):
    # Load all data
    pairs, endpoints, df_events, df_info = load_data(
        path_pairs,
        path_definitions,
        path_dense_fevents,
        path_info
    )

    # Initialize the CSV output
    line_buffering = 1
    res_file = open(output_path, "x", buffering=line_buffering)
    res_writer = init_csv(res_file)

    # Initialize the job queue
    jobs = LifoQueue()
    for pair in pairs:
        for lag in LAGS:
            jobs.put({"pair": pair, "lag": lag, "step_size": DEFAULT_STEP_SIZE})

    skip = None
    # Run the regression for each job
    while not jobs.empty():
        job = jobs.get()
        pair = job["pair"]
        lag = job["lag"]
        step_size = job["step_size"]

        logger.debug(f"Jobs remaining: ~ {jobs.qsize()}")

        if pair == skip:
            continue
        
        logger.info(f"[JOB] pair: {pair} | lag: {lag} | step size: {step_size}")
        _, outcome = pair
        is_sex_specific = pd.notna(endpoints.loc[endpoints.NAME == outcome, "SEX"].iloc[0])

        try:
            (df_controls,
             df_unexp_death,
             df_unexp_exp_p1,
             df_unexp_exp_p2,
             df_tri_p1,
             df_tri_p2) = prep_coxhr(pair, lag, df_events, df_info)

            nindivs, df_lifelines = prep_lifelines(
                df_controls,
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
            skip = pair
            logger.warning(exc)
        except (ConvergenceError, Warning) as exc:
            # Retry with a lower step_size
            if step_size == DEFAULT_STEP_SIZE:
                step_size = LOWER_STEP_SIZE
                jobs.put({"pair": pair, "lag": lag, "step_size": step_size})
            # We already tried with the lower step size, we have to skip this job
            else:
                logger.warning(f"Failed to run Cox.fit() for {pair}, lag: {lag}, step size: {step_size}:\n{exc}")

    res_file.close()


def load_data(path_pairs, path_definitions, path_dense_fevents, path_info):
    logger.info("Loading data")
    # Get pairs
    pairs = pd.read_csv(path_pairs)
    pairs = [(prior, outcome) for (prior, outcome) in pairs.to_numpy()]  # from DataFrame to Numpy array to tuple-list

    # Get endpoint list
    endpoints = pd.read_csv(path_definitions, usecols=["NAME", "SEX"])

    # Get first events
    df_events = pd.read_csv(path_dense_fevents)

    # Get sex and approximate birth date of each indiv
    df_info = pd.read_csv(path_info, usecols=["FINNGENID", "BL_YEAR", "BL_AGE", "SEX"])
    df_info["female"] = df_info.SEX == "female"
    df_info["BIRTH_TYEAR"] = df_info.BL_YEAR - df_info.BL_AGE
    df_info = df_info.drop(columns=["SEX", "BL_YEAR", "BL_AGE"])

    # Set age at start of study for each indiv.
    df_info["START_AGE"] = df_info.apply(
        lambda r: max(STUDY_STARTS - r.BIRTH_TYEAR, 0.0),
        axis="columns"
    )
    # We cannot set age at end of study yet, since it depends on the outcome age.
    # However, we need the death age for it when are there.
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
        "endpoint_coef",
        "endpoint_se",
        "endpoint_hr",
        "endpoint_ci_lower",
        "endpoint_ci_upper",
        "endpoint_pval",
        "endpoint_zval",
        "year_coef",
        "year_se",
        "year_hr",
        "year_ci_lower",
        "year_ci_upper",
        "year_pval",
        "year_zval",
        "sex_coef",
        "sex_se",
        "sex_hr",
        "sex_ci_lower",
        "sex_ci_upper",
        "sex_pval",
        "sex_zval",
    ])

    return res_writer


def prep_coxhr(pair, lag, df_events, df_info):
    logger.info(f"Preparing data before Cox fitting for {pair}")
    prior, outcome = pair

    # Define groups for the case-cohort design study.
    # Naming follows Johansson-16 paper.
    cohort = set(df_events.FINNGENID)
    cases = set(df_events.loc[df_events.ENDPOINT == outcome, "FINNGENID"])
    cc_subcohort = set(np.random.choice(list(cohort), N_SUBCOHORT, replace=False))
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
    df_weights.loc[df_weights.FINNGENID.isin(cases), "weight"] = cc_weight_non_cases
    df_info = df_info.merge(df_weights, on="FINNGENID")

    # Define groups for the unexposed/exposed study
    with_prior = set(df_events.loc[df_events.ENDPOINT == prior, "FINNGENID"])
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
    df_sample = df_sample.merge(df_outcome, on="FINNGENID", how="left")
    df_sample["END_AGE"] = pd.DataFrame({
        "outcome": df_sample.OUTCOME_AGE,
        "death": df_sample.DEATH_AGE,
        "study_ends": STUDY_ENDS - df_sample.BIRTH_TYEAR,
    }).min(axis="columns")

    # Move endpoint to study start if it happened before the study
    exposed_before_study = df_sample.PRIOR_AGE < df_sample.START_AGE
    df_sample.loc[exposed_before_study, "PRIOR_AGE"] = df_sample.loc[exposed_before_study, "START_AGE"]

    # Controls
    controls = np.random.choice(list(unexp), N_SUBCOHORT, replace=False)
    df_controls = df_sample.loc[df_sample.FINNGENID.isin(controls), :].copy()
    df_controls["duration"] = df_controls.END_AGE - df_controls.START_AGE
    df_controls["prior"] = False
    df_controls["outcome"] = False

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
        duration = df_unexp_exp_p2.apply(
            lambda r: min(r.END_AGE - r.PRIOR_AGE, lag),
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
        duration = df_tri_p2.apply(
            lambda r: min(r.END_AGE - r.PRIOR_AGE, lag),
            axis="columns"
        )
        outcome = (df_tri_p2.END_AGE - df_tri_p2.PRIOR_AGE) < lag
    df_tri_p2["duration"] = duration
    df_tri_p2["outcome"] = outcome

    return (
        df_controls,
        df_unexp_outcome,
        df_unexp_exp_p1,
        df_unexp_exp_p2,
        df_tri_p1,
        df_tri_p2
    )


def prep_lifelines(df_controls, df_unexp_death, df_unexp_exp_p1, df_unexp_exp_p2, df_tri_p1, df_tri_p2):
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
        df_controls.loc[:, keep_cols],
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
    censored = df.prior & ~ df.outcome
    if lag is None:
        predict_at = STUDY_ENDS - STUDY_STARTS
    else:
        predict_at = lag
    pred_risk = cph.predict_survival_function(
        df.loc[censored, :],
        times=[predict_at]
    )
    absolute_risk = pred_risk.mean(axis="columns").values[0]

    # Get values out of the fitted model
    prior_coef = cph.params_["prior"]
    prior_se = cph.standard_errors_["prior"]
    prior_hr = np.exp(prior_coef)
    prior_ci_lower = np.exp(prior_coef - 1.96 * prior_se)
    prior_ci_upper = np.exp(prior_coef + 1.96 * prior_se)
    prior_pval = cph.summary.p["prior"]
    prior_zval = cph.summary.z["prior"]

    year_coef = cph.params_["BIRTH_TYEAR"]
    year_se = cph.standard_errors_["BIRTH_TYEAR"]
    year_hr = np.exp(year_coef)
    year_ci_lower = np.exp(year_coef - 1.96 * year_se)
    year_ci_upper = np.exp(year_coef + 1.96 * year_se)
    year_pval = cph.summary.p["BIRTH_TYEAR"]
    year_zval = cph.summary.z["BIRTH_TYEAR"]

    if not is_sex_specific:
        sex_coef = cph.params_["female"]
        sex_se = cph.standard_errors_["female"]
        sex_hr = np.exp(sex_coef)
        sex_ci_lower = np.exp(sex_coef - 1.96 * sex_se)
        sex_ci_upper = np.exp(sex_coef + 1.96 * sex_se)
        sex_pval = cph.summary.p["female"]
        sex_zval = cph.summary.z["female"]
    else:
        sex_coef = np.nan
        sex_se = np.nan
        sex_hr = np.nan
        sex_ci_lower = np.nan
        sex_ci_upper = np.nan
        sex_pval = np.nan
        sex_zval = np.nan

    # Save values
    res_writer.writerow([
        prior,
        outcome,
        lag,
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
        year_coef,
        year_se,
        year_hr,
        year_ci_lower,
        year_ci_upper,
        year_pval,
        year_zval,
        sex_coef,
        sex_se,
        sex_hr,
        sex_ci_lower,
        sex_ci_upper,
        sex_pval,
        sex_zval
    ])
    logger.info("done running Cox regression")


if __name__ == '__main__':
    INPUT_PAIRS = Path(argv[1])
    INPUT_DEFINITIONS = Path(argv[2])
    INPUT_DENSE_FEVENTS = Path(argv[3])
    INPUT_INFO = Path(argv[4])
    OUTPUT = Path(argv[5])

    main(
        INPUT_PAIRS,
        INPUT_DEFINITIONS,
        INPUT_DENSE_FEVENTS,
        INPUT_INFO,
        OUTPUT
    )
