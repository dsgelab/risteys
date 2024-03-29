"""
Mortality statistics.

This script compute statistics on mortality.
It is done using survival analysis with the Cox PH method.

References
----------
- CASE-COHORT
  https://www.stata.com/meeting/nordic-and-baltic16/slides/norway16_johansson.pdf
- NB COMO
  https://plana-ripoll.github.io/NB-COMO/
"""
from csv import writer as csv_writer
from pathlib import Path
from sys import argv
from time import time as now

import numpy as np
import pandas as pd
from lifelines import CoxPHFitter
from lifelines.utils import ConvergenceError
from lifelines.utils import interpolate_at_times

from log import logger


STUDY_STARTS = 1998.0  # inclusive
STUDY_ENDS = 2021.99   # inclusive, using same number format as FinnGen data files

N_SUBCOHORT = 10_000
# Minimum number of individuals having both the endpoint and died,
# this must be > 5 to not be deemed as containing individual-level data.
MIN_INDIVS = 10

class NotEnoughIndividuals(Exception):
    pass

# Column names for lagged HR
LAG_COLS = {
    None: {
        "duration": "duration",
        "death": "death"
    },
    (5, 15): {
        "duration": "duration_15y",
        "death": "death_15y"
    },
    (1, 5): {
        "duration": "duration_5y",
        "death": "death_5y"
    },
    (0, 1): {
        "duration": "duration_1y",
        "death": "death_1y"
    }
}


# Used for HR re-computation
BCH_TIMEPOINTS = [0, 2.5, 5, 7.5, 10, 12.5, 15, 17.5, 20, 21.99]


def main(path_definitions, path_long_format_fevents, path_info, output_path, timings_path):
    endpoints, df_events, df_info = load_data(path_definitions, path_long_format_fevents, path_info)

    line_buffering = 1
    res_file = open(output_path, "x", buffering=line_buffering)
    res_writer = init_csv(res_file)

    # File that keep tracks of how much time was spent on each endpoint
    timings_file = open(timings_path, "x", buffering=line_buffering)
    timings_writer = csv_writer(timings_file)
    timings_writer.writerow(["endpoint", "lags_computed", "time_seconds"])

    for _, endpoint in endpoints.iterrows():
        time_start = now()
        lags_computed = 0
        try:
            (df_controls,
             df_unexp_death,
             df_unexp_exp_p1,
             df_unexp_exp_p2,
             df_tri_p1,
             df_tri_p2) = prep_coxhr(endpoint, df_events, df_info)

            for lag, cols in LAG_COLS.items():
                logger.info(f"Setting HR lag to: {lag}")
                nindivs, df_lifelines = prep_lifelines(
                    cols,
                    df_controls,
                    df_unexp_death,
                    df_unexp_exp_p1,
                    df_unexp_exp_p2,
                    df_tri_p1,
                    df_tri_p2
                )
                compute_coxhr(
                    endpoint,
                    df_lifelines,
                    lag,
                    nindivs,
                    res_writer
                )
                lags_computed += 1
        except NotEnoughIndividuals as exc:
            logger.warning(exc)
        except ConvergenceError as exc:
            logger.warning(f"Failed to run Cox.fit():\n{exc}")
        finally:
            endpoint_time = now() - time_start
            timings_writer.writerow([endpoint.NAME, lags_computed, endpoint_time])

    timings_file.close()
    res_file.close()


def load_data(path_definitions, path_long_format_fevents, path_info):
    logger.info("Loading data")
    # Get endpoint list
    endpoints = pd.read_csv(path_definitions, usecols=["NAME", "SEX", "CORE_ENDPOINTS"])

    # Get first events
    df_events = pd.read_parquet(path_long_format_fevents)

    # Keep only core endpoints
    endpoints = endpoints.loc[endpoints.CORE_ENDPOINTS == "yes", :]
    select_endpoints = set(endpoints.NAME).union(["DEATH"])  # we need the DEATH endpoint to compute mortality
    df_events = df_events.loc[df_events.ENDPOINT.isin(select_endpoints), :]

    # Get sex and approximate birth date of each indiv
    df_info = pd.read_csv(path_info, usecols=["FINNGENID", "BL_YEAR", "BL_AGE", "SEX"])
    df_info["female"] = df_info.SEX == "female"
    df_info = df_info.loc[(~ df_info.BL_YEAR.isna()) & (~ df_info.BL_AGE.isna()), :]  # remove individuals without time info
    df_info["BIRTH_TYEAR"] = df_info.BL_YEAR - df_info.BL_AGE
    df_info = df_info.drop(columns=["SEX", "BL_YEAR", "BL_AGE"])

    # Set age at start and end of study for each indiv
    df_info["START_AGE"] = df_info.apply(
        lambda r: max(STUDY_STARTS - r.BIRTH_TYEAR, 0.0),
        axis="columns"
    )
    deaths = (
        df_events.loc[df_events.ENDPOINT == "DEATH", ["FINNGENID", "AGE"]]
        .rename(columns={"AGE": "DEATH_AGE"})
    )
    df_info = df_info.merge(deaths, on="FINNGENID", how="left")
    df_info["END_AGE"] = df_info.apply(
        # We cannot simply use min() or max() here due to NaN, so we resort to an if-else
        lambda r: r.DEATH_AGE if (r.BIRTH_TYEAR + r.DEATH_AGE) < STUDY_ENDS else (STUDY_ENDS - r.BIRTH_TYEAR),
        axis="columns"
    )

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

    logger.info("done loading data")
    return endpoints, df_events, df_info


def init_csv(res_file):
    res_writer = csv_writer(res_file)
    res_writer.writerow([
        "endpoint",
        "lag_hr",
        "nindivs_prior_later",
        "absolute_risk",
        "endpoint_coef",
        "endpoint_se",
        "endpoint_hr",
        "endpoint_ci_lower",
        "endpoint_ci_upper",
        "endpoint_pval",
        "endpoint_zval",
        "endpoint_norm_mean",
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


def prep_coxhr(endpoint, df_events, df_info):
    logger.info(f"Preparing data before Cox fitting for {endpoint.NAME}")

    # Define groups for the case-cohort design study.
    # Naming follows Johansson-16 paper.
    cohort = set(df_events.FINNGENID)
    cases = set(df_events.loc[df_events.ENDPOINT == "DEATH", "FINNGENID"])
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

    # Define groups for the unexposed/exposed study
    with_endp = set(df_events.loc[df_events.ENDPOINT == endpoint.NAME, "FINNGENID"])
    unexp           = cohort - with_endp - cases
    unexp_death     = cases - with_endp
    unexp_exp       = with_endp - cases
    unexp_exp_death = with_endp & cases
    assert len(cohort) == (len(unexp) + len(unexp_death) + len(unexp_exp) + len(unexp_exp_death))

    # Check that we have enough individuals to do the study
    nindivs = len(unexp_exp_death)
    if nindivs < MIN_INDIVS:
        raise NotEnoughIndividuals(f"Not enough individuals having endpoint({endpoint.NAME}) and death: {nindivs} < {MIN_INDIVS}")
    elif len(unexp_exp) < MIN_INDIVS:
        raise NotEnoughIndividuals(f"Not enougth individuals in group: endpoint({endpoint.NAME}) + no death, {len(unexp_exp)} < {MIN_INDIVS}")

    # Merge endpoint data with info data
    df_endp = (
        df_events.loc[df_events.ENDPOINT == endpoint.NAME, ["FINNGENID", "AGE"]]
        .rename(columns={"AGE": "ENDPOINT_AGE"})
    )
    df_sample = df_info.merge(df_endp, on="FINNGENID", how="left")  # left join to keep individuals not having the endpoint

    # Move endpoint to study start if it happened before the study
    exposed_before_study = df_sample.ENDPOINT_AGE < df_sample.START_AGE
    df_sample.loc[exposed_before_study, "ENDPOINT_AGE"] = df_sample.loc[exposed_before_study, "START_AGE"]

    # Unexposed
    df_unexp = df_sample.loc[df_sample.FINNGENID.isin(unexp), :].copy()
    df_unexp["duration"] = df_unexp.END_AGE - df_unexp.START_AGE
    df_unexp["endpoint"] = False
    df_unexp["death"] = False

    # Unexposed -> Death
    df_unexp_death = df_sample.loc[df_sample.FINNGENID.isin(unexp_death), :].copy()
    df_unexp_death["duration"] = df_unexp_death.DEATH_AGE - df_unexp_death.START_AGE
    df_unexp_death["endpoint"] = False
    df_unexp_death["death"] = True

    # Unexposed -> Exposed: need time-window splitting
    df_unexp_exp = df_sample.loc[df_sample.FINNGENID.isin(unexp_exp), :].copy()
    # Phase 1: unexposed
    df_unexp_exp_p1 = df_unexp_exp.copy()
    df_unexp_exp_p1["duration"] = df_unexp_exp_p1.ENDPOINT_AGE - df_unexp_exp_p1.START_AGE
    df_unexp_exp_p1["endpoint"] = False
    df_unexp_exp_p1["death"] = False
    # Phase 2: exposed
    df_unexp_exp_p2 = df_unexp_exp.copy()
    df_unexp_exp_p2["endpoint"] = True
    for lag, cols in LAG_COLS.items():
        if lag is None:  # no lag HR
            duration = df_unexp_exp_p2.END_AGE - df_unexp_exp_p2.ENDPOINT_AGE
        else:
            _min_lag, max_lag = lag
            duration = df_unexp_exp_p2.apply(
                lambda r: min(r.END_AGE - r.ENDPOINT_AGE, max_lag),
                axis="columns"
            )
        df_unexp_exp_p2[cols["duration"]] = duration
        df_unexp_exp_p2[cols["death"]] = False

    # Unexposed -> Exposed -> Death: need time-window splitting
    df_tri = df_sample.loc[df_sample.FINNGENID.isin(unexp_exp_death), :].copy()
    # Phase 1: unexposed
    df_tri_p1 = df_tri.copy()
    df_tri_p1["duration"] = df_tri_p1.ENDPOINT_AGE - df_tri_p1.START_AGE
    df_tri_p1["endpoint"] = False
    df_tri_p1["death"] = False
    # Phase 2: exposed
    df_tri_p2 = df_tri.copy()
    df_tri_p2["endpoint"] = True
    for lag, cols in LAG_COLS.items():
        if lag is None:
            duration = df_tri_p2.DEATH_AGE - df_tri.ENDPOINT_AGE
            death = True
        else:
            min_lag, max_lag = lag
            duration = df_tri_p2.apply(
                lambda r: min(r.DEATH_AGE - r.ENDPOINT_AGE, max_lag),
                axis="columns"
            )
            death_time = df_tri_p2.DEATH_AGE - df_tri_p2.ENDPOINT_AGE
            death = (death_time >= min_lag) & (death_time <= max_lag)
        df_tri_p2[cols["duration"]] = duration
        df_tri_p2[cols["death"]] = death

    logger.info("done preparing the data")
    return (
        df_unexp,
        df_unexp_death,
        df_unexp_exp_p1,
        df_unexp_exp_p2,
        df_tri_p1,
        df_tri_p2
    )


def prep_lifelines(cols, df_unexp, df_unexp_death, df_unexp_exp_p1, df_unexp_exp_p2, df_tri_p1, df_tri_p2):
    logger.info("Preparing lifelines dataframes")

    # Rename lagged HR columns
    col_duration = cols["duration"]
    col_death = cols["death"]
    keep_cols_p2 = [col_duration, "endpoint", "BIRTH_TYEAR", "female", col_death, "weight"]
    df_unexp_exp_p2 = (
        df_unexp_exp_p2.loc[:, keep_cols_p2]
        .rename(columns={col_duration: "duration", col_death: "death"})
    )
    df_tri_p2 = (
        df_tri_p2.loc[:, keep_cols_p2]
        .rename(columns={col_duration: "duration", col_death: "death"})
    )

    # Re-check that there are enough individuals to do the study,
    # since after setting the lag some individuals might not have the
    # death outcome anymore.
    nindivs, _ =  df_tri_p2.loc[df_tri_p2.endpoint & df_tri_p2.death, :].shape
    if nindivs < MIN_INDIVS:
        raise NotEnoughIndividuals(f"not enough individuals with lag")

    # Concatenate the data frames together
    keep_cols = ["duration", "endpoint", "BIRTH_TYEAR", "female", "death", "weight"]
    df_lifelines = pd.concat([
        df_unexp.loc[:, keep_cols],
        df_unexp_death.loc[:, keep_cols],
        df_unexp_exp_p1.loc[:, keep_cols],
        df_unexp_exp_p2,
        df_tri_p1.loc[:, keep_cols],
        df_tri_p2],
        ignore_index=True)

    logger.info("done preparing lifelines dataframes")
    return nindivs, df_lifelines


def compute_coxhr(endpoint, df, lag, nindivs, res_writer):
    logger.info(f"Running Cox regression")
    # Handle sex-specific endpoints
    is_sex_specific = pd.notna(endpoint.SEX)
    if is_sex_specific:
        df = df.drop(columns=["female"])

    # Fit Cox model
    cph = CoxPHFitter()

    cph.fit(
        df,
        duration_col="duration",
        event_col="death",
        # For the case-cohort study we need weights and robust errors:
        weights_col="weight",
        robust=True
    )


    # Compute absolute risk
    mean_indiv = {
        "BIRTH_TYEAR": [1959.0],
        "endpoint": [True],
        "female": [0.5]
    }

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
        pd.DataFrame(mean_indiv),
        times=[predict_at]
    ).values[0][0]
    absolute_risk = 1 - surv_probability

    norm_mean = cph._norm_mean
    # Get values out of the fitted model
    endp_coef = cph.params_["endpoint"]
    endp_se = cph.standard_errors_["endpoint"]
    endp_hr = np.exp(endp_coef)
    endp_ci_lower = np.exp(endp_coef - 1.96 * endp_se)
    endp_ci_upper = np.exp(endp_coef + 1.96 * endp_se)
    endp_pval = cph.summary.p["endpoint"]
    endp_zval = cph.summary.z["endpoint"]
    endp_norm_mean = norm_mean["endpoint"]

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
        endpoint.NAME,
        lag_value,
        nindivs,
        absolute_risk,
        endp_coef,
        endp_se,
        endp_hr,
        endp_ci_lower,
        endp_ci_upper,
        endp_pval,
        endp_zval,
        endp_norm_mean,
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
    logger.info("done running Cox regression")


def bch_at(df, time):
    try:
        res = df.loc[time, "baseline cumulative hazard"]
    except KeyError:
        # Index of the BCH dataframe are floats, which may not be exact values, so we check for the closest one
        res = interpolate_at_times(df, [time])[0]
    return res


if __name__ == '__main__':
    INPUT_DEFINITIONS = Path(argv[1])
    INPUT_DENSE_FEVENTS = Path(argv[2])
    INPUT_INFO = Path(argv[3])
    OUTPUT = Path(argv[4])
    TIMINGS = Path(argv[5])

    main(
        INPUT_DEFINITIONS,
        INPUT_DENSE_FEVENTS,
        INPUT_INFO,
        OUTPUT,
        TIMINGS
    )
