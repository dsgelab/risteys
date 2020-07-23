from csv import writer as csv_writer
from pathlib import Path
from sys import argv

import numpy as np
import pandas as pd
from lifelines import CoxPHFitter
from lifelines.utils import ConvergenceError

from log import logger


STUDY_STARTS = 1998.0  # inclusive
STUDY_ENDS = 2019.99   # inclusive, using same number format as FinnGen data files

MAX_CONTROLS = 10_000
MIN_CASES = 10
class NotEnoughCases(Exception):
    pass


def main(path_definitions, path_dense_fevents, path_info, output_path):
    endpoints, df_events, df_info = load_data(path_definitions, path_dense_fevents, path_info)

    line_buffering = 1
    res_file = open(output_path, "x", buffering=line_buffering)
    res_writer = init_csv(res_file)

    for _, endpoint in endpoints.iterrows():
        try:
            df_durations = prep_coxhr(endpoint, df_events, df_info)
            compute_coxhr(endpoint, df_durations, res_writer)
        except NotEnoughCases:
            logger.warning(f"Not enough cases for {endpoint.NAME}")
        except ConvergenceError as exc:
            logger.warning("Failed to run Cox.fit():\n{exc}")

    res_file.close()


def load_data(path_definitions, path_dense_fevents, path_info):
    logger.info("Loading data")
    # Get endpoint list
    endpoints = pd.read_csv(path_definitions, usecols=["NAME", "SEX"])

    # Get first events
    df_events = pd.read_csv(path_dense_fevents)

    # Get sex and approximate birth date of each indiv
    df_info = pd.read_csv(path_info, usecols=["FINNGENID", "BL_YEAR", "BL_AGE", "SEX"])
    df_info["female"] = df_info.SEX == "female"
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


def prep_coxhr(endpoint, df_events, df_info):
    logger.info(f"Preparing data before Cox fitting for {endpoint.NAME}")
    all_indivs = set(df_events.FINNGENID)
    with_endp  = set(df_events.loc[df_events.ENDPOINT == endpoint.NAME, "FINNGENID"])
    with_death = set(df_events.loc[df_events.ENDPOINT == "DEATH", "FINNGENID"])

    unexp           = all_indivs - with_endp - with_death  # control group
    unexp_death     = with_death - with_endp
    unexp_exp       = with_endp  - with_death
    unexp_exp_death = with_endp  & with_death

    assert len(all_indivs) == (len(unexp) + len(unexp_death) + len(unexp_exp) + len(unexp_exp_death))
    if len(unexp_exp_death) < MIN_CASES:
        raise NotEnoughCases

    # Merge endpoint data with info data
    df_endp = (
        df_events.loc[df_events.ENDPOINT == endpoint.NAME, ["FINNGENID", "AGE"]]
        .rename(columns={"AGE": "ENDPOINT_AGE"})
    )
    df_merge = df_info.merge(df_endp, on="FINNGENID", how="left")

    # Move endpoint to study start if it happened before the study
    exposed_before_study = df_merge.ENDPOINT_AGE < df_merge.START_AGE
    df_merge.loc[exposed_before_study, "ENDPOINT_AGE"] = df_merge.loc[exposed_before_study, "START_AGE"]

    # Controls
    controls = np.random.choice(list(unexp), MAX_CONTROLS, replace=False)
    df_controls = df_merge.loc[df_merge.FINNGENID.isin(controls), :].copy()
    df_controls["duration"] = df_controls.END_AGE - df_controls.START_AGE
    df_controls["endpoint"] = False
    df_controls["death"] = False

    # Unexposed -> Death
    df_unexp_death = df_merge.loc[df_merge.FINNGENID.isin(unexp_death), :].copy()
    df_unexp_death["duration"] = df_unexp_death.DEATH_AGE - df_unexp_death.START_AGE
    df_unexp_death["endpoint"] = False
    df_unexp_death["death"] = True

    # Unexposed -> Exposed: need time-window splitting
    df_unexp_exp = df_merge.loc[df_merge.FINNGENID.isin(unexp_exp), :].copy()
    # Phase 1: unexposed
    df_unexp_exp_p1 = df_unexp_exp.copy()
    df_unexp_exp_p1["duration"] = df_unexp_exp_p1.ENDPOINT_AGE - df_unexp_exp_p1.START_AGE
    df_unexp_exp_p1["endpoint"] = False
    df_unexp_exp_p1["death"] = False
    # Phase 2: exposed
    df_unexp_exp_p2 = df_unexp_exp.copy()
    df_unexp_exp_p2["duration"] = df_unexp_exp_p2.END_AGE - df_unexp_exp_p2.ENDPOINT_AGE
    df_unexp_exp_p2["endpoint"] = True
    df_unexp_exp_p2["death"] = False

    # Unexposed -> Exposed -> Death: need time-window splitting
    df_tri = df_merge.loc[df_merge.FINNGENID.isin(unexp_exp_death), :].copy()
    # Phase 1: unexposed
    df_tri_p1 = df_tri.copy()
    df_tri_p1["duration"] = df_tri_p1.ENDPOINT_AGE - df_tri_p1.START_AGE
    df_tri_p1["endpoint"] = False
    df_tri_p1["death"] = False
    # Phase 2: exposed
    df_tri_p2 = df_tri.copy()
    df_tri_p2["duration"] = df_tri_p2.DEATH_AGE - df_tri.ENDPOINT_AGE
    df_tri_p2["endpoint"] = True
    df_tri_p2["death"] = True

    keep_cols = ["duration", "endpoint", "BIRTH_TYEAR", "female", "death"]
    df_durations = pd.concat([
        df_controls.loc[:, keep_cols],
        df_unexp_death.loc[:, keep_cols],
        df_unexp_exp_p1.loc[:, keep_cols],
        df_unexp_exp_p2.loc[:, keep_cols],
        df_tri_p1.loc[:, keep_cols],
        df_tri_p2.loc[:, keep_cols]],
        ignore_index=True)

    logger.info("done preparing data")
    return df_durations


def compute_coxhr(endpoint, df, res_writer):
    logger.info(f"Running Cox regression")
    # Handle sex-specific endpoints
    is_sex_specific = pd.notna(endpoint.SEX)
    if is_sex_specific:
        df = df.drop(columns=["female"])

    # Fit Cox model
    cph = CoxPHFitter()

    cph.fit(df, duration_col="duration", event_col="death")

    # Get values out of the fitted model
    endp_coef = cph.params_["endpoint"]
    endp_se = cph.standard_errors_["endpoint"]
    endp_hr = np.exp(endp_coef)
    endp_ci_lower = np.exp(endp_coef - 1.96 * endp_se)
    endp_ci_upper = np.exp(endp_coef + 1.96 * endp_se)
    endp_pval = cph.summary.p["endpoint"]
    endp_zval = cph.summary.z["endpoint"]

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

    # Save values
    res_writer.writerow([
        endpoint.NAME,
        endp_coef,
        endp_se,
        endp_hr,
        endp_ci_lower,
        endp_ci_upper,
        endp_pval,
        endp_zval,
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
    INPUT_DEFINITIONS = Path(argv[1])
    INPUT_DENSE_FEVENTS = Path(argv[2])
    INPUT_INFO = Path(argv[3])
    OUTPUT = Path(argv[4])

    main(
        INPUT_DEFINITIONS,
        INPUT_DENSE_FEVENTS,
        INPUT_INFO,
        OUTPUT
    )
