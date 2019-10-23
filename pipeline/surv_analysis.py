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
- INPUT_PHENOTYPES
- INPUT_PAIRS
- OUTPUT_NAME
- OUTPUT_ERROR
and run:
  python surv_analysis.py


Input files
-----------
- INPUT_PHENOTYPES
  The first-event phenotype file from FinnGen.

- INPUT_PAIRS
  CSV file containing a list of pairs to do survival analysis of.
  This file header is: prior,later

Output files
------------
- OUTPUT_NAME
   Result file, as CSV, one line per endpoint pair.
- OUTPUT_ERROR
   Where to log errors, one line per endpoint pair.

Description
-----------
Do Cox regressions on the provided endpoint pairs. Each regression
will return metrics of interest, such as hazard ratio and p-value.

Data is first processed to sort out what individuals to take and how
they are distributed with respect to the prior- and later-endpoints.


References
----------
[1] https://github.com/DataBiosphere/dsub/
"""

import csv
import logging
from pathlib import Path
from os import getenv
from warnings import filterwarnings

import numpy as np
import pandas as pd
from lifelines import CoxPHFitter
from lifelines.utils import ConvergenceError



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


# As required by dsub, file paths are taken from the environment
# variables.
INPUT_PHENOTYPES = Path(getenv("INPUT_PHENOTYPES"))
INPUT_PAIRS = Path(getenv("INPUT_PAIRS"))
INPUT_DEFINITIONS = Path(getenv("INPUT_DEFINITIONS"))
OUTPUT_NAME = Path(getenv("OUTPUT_NAME"))
OUTPUT_ERROR = Path(getenv("OUTPUT_ERROR"))


# Year of study starts
STUDY_STARTS = 1998.0
STUDY_ENDS = 2018.0

# Columns to always keep
KEEP = [
    "BL_AGE", "BL_YEAR",
    "DEATH_AGE", "DEATH_YEAR", "DEATH",
    "SEX"
]
# Column suffixes
SUFFIX_AGE = "_AGE"
SUFFIX_YEAR = "_YEAR"

# Catch warning from lifelines
filterwarnings(action="error", module="lifelines")


def prechecks(pairs_path, phenotypes_path, definitions_path, output_path, error_path):
    """Perform checks before running to fail early"""
    logger.info("Performing pre-checks")
    assert phenotypes_path.exists(), f"{phenotypes_path} doesn't exist"
    assert pairs_path.exists(), f"{pairs_path} doesn't exist"
    assert definitions_path.exists(), f"{definitions_path} doesn't exist"
    assert not output_path.exists(), f"{output_path} already exists, not overwriting it"
    assert not error_path.exists(), f"{error_path} already exists, not overwriting it"


def main(pairs_path, phenotypes_path, definitions_path, output_path, error_path):
    """Run Cox regressions on all provided pairs of endpoints"""
    prechecks(pairs_path, phenotypes_path, definitions_path, output_path, error_path)

    pairs, df, endpoints, definitions = load_data(pairs_path, phenotypes_path, definitions_path)

    df = clean_data(df, endpoints)

    res_writer, res_file, error_writer, error_file = create_csv_writers(output_path, error_path)

    pairs.apply(
        lambda p: compute_coxhr(p, df, definitions, res_writer, error_writer),
        axis=1,
        result_type="expand"
    )

    error_file.close()
    res_file.close()

    logger.info("Done")


def create_csv_writers(output_path, error_path):
    """Create CSV writers for outputting results and errors."""
    line_buffering = 1  # really write to file after each line

    res_file = open(output_path, "x", buffering=line_buffering)
    res_writer = csv.writer(res_file)
    res_writer.writerow([
        "prior",
        "later",
        "nindivs_prior_later",
        "median_duration",
        "pred_coef",
        "pred_se",
        "pred_hr",
        "pred_ci_lower",
        "pred_ci_upper",
        "pred_pval",
        "pred_zval",
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
        "nsubjects",
        "nevents",
        "partial_log_likelihood",
        "concordance",
        "log_likelihood_ratio_test",
        "log_likelihood_ndf",
        "log_likelihood_pval",
    ])

    error_file = open(error_path, "x", buffering=line_buffering)
    error_writer = csv.writer(error_file)
    error_writer.writerow(["prior", "later", "type", "message"])

    return res_writer, res_file, error_writer, error_file


def load_data(pairs_path, phenotypes_path, definitions_path):
    """Load the relevant columns from the phenotype data"""
    logger.info("Loading data")

    # Check all columns of phenotype file
    pheno_cols = pd.read_csv(
        phenotypes_path,
        dialect=csv.excel_tab,
        nrows=0  # get only the header
    )

    pairs = pd.read_csv(pairs_path)

    # Some endpoints can be in in the pair list but not in the columns
    # of the phenotype file. This is because the pair list was made
    # from the longitudinal file, which unfortunately has endpoints
    # that does not match in the phenotype file. To solve this, we
    # take only endpoints present in the phenotype file.
    # Another solution would be to make the indivs × first event
    # matrix from the longitudinal file, and include the extra
    # information such as baseline age and sex.
    endpoints = set.union(set(pairs.prior), set(pairs.later))
    endpoints = set.intersection(endpoints, set(pheno_cols))
    # Remove inacessible endpoints from the list of pairs
    pairs = pairs[
        pairs.prior.isin(endpoints)
        & pairs.later.isin(endpoints)
    ]

    cols = []
    for endpoint in endpoints:
        cols.append(endpoint)
        cols.append(endpoint + SUFFIX_AGE)
    cols += KEEP

    phenotypes = pd.read_csv(
        phenotypes_path,
        dialect=csv.excel_tab,
        usecols=cols
    )

    # Endpoint definitions to check for sex-specific endpoints
    definitions = pd.read_csv(
        definitions_path,
        dialect=csv.excel_tab,
        usecols=["NAME", "SEX"]
    )

    return pairs, phenotypes, endpoints, definitions


def clean_data(df, endpoints):
    """Set correct data type and deal with year/age for study start and end."""
    logger.info("Cleaning data")
    # Some columns have values: 0, 1, NaN. Replace all NaN by 0.
    df.loc[:, endpoints] = df.loc[:, endpoints].fillna(0)

    # Set endpoint indicator as boolean instead of 0 or 1
    types = {e : np.bool for e in endpoints}
    types["DEATH"] = np.bool
    df = df.astype(types)

    # Set SEX=1 for males and SEX=2 for females
    df.loc[:, "SEX"] = df.loc[:, "SEX"].replace({"female": 2, "male": 1})

    # Set _AGE to NaN for individuals that have endpoint = False
    for endpoint in endpoints:
        df.loc[~ df[endpoint], endpoint + SUFFIX_AGE] = np.nan
    df.loc[~ df.DEATH, ["DEATH" + SUFFIX_AGE, "DEATH" + SUFFIX_YEAR]] = np.nan

    # Consider events to happen at the middle of the year since we
    # only have a year resolution.
    mid_year = 0.5
    df["birth_year"] = df["BL_YEAR"] + mid_year - df["BL_AGE"]

    df["study_starts_age"] = STUDY_STARTS - df["birth_year"]
    df["study_ends_age"] = STUDY_ENDS - df["birth_year"]

    # Remove individuals that died before the study
    death_before_study = df.DEATH_AGE < df.study_starts_age
    df = df[~ death_before_study]

    return df


def compute_coxhr(pair, df, definitions, res_writer, error_writer):
    """Shape the data for the Cox regression, then do the regression"""
    prior, later = pair
    logger.info(f"Preparing data for Cox regression on ({prior}, {later})")

    prior_age = prior + SUFFIX_AGE
    later_age = later + SUFFIX_AGE

    # Check if outcome endpoint is sex-specific
    is_sex_specific = pd.notna(definitions.loc[definitions.NAME == later, "SEX"].iloc[0])

    # Remove individuals having "later" event (prevalent) before study starts
    pseudo_later_year = df["birth_year"] + df[later_age]
    later_before_study = pseudo_later_year < STUDY_STARTS
    df = df[~ later_before_study].copy()

    # For individuals with prior before study starts: ignore time before study
    prior_before_study = df[prior_age] < df.study_starts_age
    df.loc[prior_before_study, prior_age] = df.loc[prior_before_study, "study_starts_age"]

    # Set start time
    df["start_age"] = df.loc[:, [0.0, "study_starts_age"]].max(axis=1)

    # Set stop time
    df["stop_age"] = df.loc[:, ["DEATH_AGE", later_age, "study_ends_age"]].min(axis=1)

    # Ignore events outside of start / stop time
    prior_outside = (df[prior_age] < df.study_starts_age) | (df[prior_age] > df.study_ends_age)
    df.loc[prior_outside, prior] = False
    df.loc[prior_outside, prior_age] = np.nan

    later_outside = (df[later_age] < df.study_starts_age) | (df[later_age] > df.study_ends_age)
    df.loc[later_outside, later] = False
    df.loc[later_outside, later_age] = np.nan

    # Split times for individuals with prior endpoint
    has_no_prior = ~ df[prior]
    has_only_prior = df[prior] & (~ df[later])
    has_prior_before_later = df[prior] & df[later] & (df[prior_age] < df[later_age])
    has_prior_after_later = df[prior] & df[later] & (df[prior_age] > df[later_age])
    nindivs, _ = df[has_prior_before_later].shape

    no_prior = df.loc[has_no_prior, :].copy()
    no_prior["outcome"] = no_prior[later]
    no_prior["pred_prior"] = False

    prior_after_later = df.loc[has_prior_after_later, :].copy()
    prior_after_later["outcome"] = True
    prior_after_later["pred_prior"] = False  # ignored since happens after the outcome

    unexposed = df.loc[has_only_prior | has_prior_before_later, :].copy()
    unexposed["stop_age"] = unexposed[prior_age]
    unexposed["pred_prior"] = False
    unexposed["outcome"] = False

    exposed = df.loc[has_only_prior | has_prior_before_later, :].copy()
    n_exposed, _ = exposed.shape
    if n_exposed > 0:  # prevent Pandas error of creating column on empty DataFrame
        exposed["start_age"] = exposed[prior_age]
        exposed["pred_prior"] = True
        exposed.loc[has_only_prior, "outcome"] = False
        exposed.loc[has_prior_before_later, "outcome"] = True

    df = pd.concat([no_prior, unexposed, exposed])

    # Compute durations
    df["duration"] = df["stop_age"] - df["start_age"]

    # Due to float precision, events happening on the same day can
    # cause duration to be very close to, but not exactly, 0. So we
    # set durations to 0 for those that are < 𝜀.
    epsilon = 1e-5
    df.loc[df.duration < epsilon, "duration"] = 0

    # Make sure that all durations are >0
    neg_durations = df["duration"] < 0
    try:
        assert (~ neg_durations).all(), f"Some durations are < 0:\n{df.loc[neg_durations, [prior, later, 'duration']]}"
    except AssertionError as e:
        logger.warning("Some durations < 0")
        error_writer.writerow([prior, later, "AssertionError", e])
    else:
        cox_fit(df, prior, later, nindivs, is_sex_specific, res_writer, error_writer)

def cox_fit(df, prior, later, nindivs, is_sex_specific, res_writer, error_writer):
    """Fit the data for the Cox regression and write output to result file"""
    logger.info("Computing Cox regression")
    cph = CoxPHFitter()

    # Set covariates depending on outcome being sex-specific
    cols = ["duration", "outcome", "pred_prior", "birth_year"]
    if not is_sex_specific:
        cols.append("SEX")
    df = df.loc[:, cols]

    # Compute the median duration for those with the prior->outcome association
    median_duration = df.loc[df.pred_prior & df.outcome, "duration"].median()

    # Set default values in case of error
    pred_coef = np.nan
    pred_se = np.nan
    pred_hr = np.nan
    pred_ci_lower = np.nan
    pred_ci_upper = np.nan
    pred_pval = np.nan
    pred_zval = np.nan

    year_coef = np.nan
    year_se = np.nan
    year_hr = np.nan
    year_ci_lower = np.nan
    year_ci_upper = np.nan
    year_pval = np.nan
    year_zval = np.nan

    sex_coef = np.nan
    sex_se = np.nan
    sex_hr = np.nan
    sex_ci_lower = np.nan
    sex_ci_upper = np.nan
    sex_pval = np.nan
    sex_zval = np.nan

    nsubjects = np.nan
    nevents = np.nan
    partial_log_likelihood = np.nan
    concordance = np.nan
    log_likelihood_ratio_test = np.nan
    log_likelihood_ndf = np.nan
    log_likelihood_pval = np.nan

    try:
        cph.fit(
            df,
            duration_col="duration",
            event_col="outcome",
            show_progress=False,
            # step_size=0.1,  # may help with convergence
        )
    except ConvergenceError as e:
        logger.warning(f"Could not fit Cox model for pair ({prior}, {later})")
        error_writer.writerow([prior, later, "ConvergenceError", e])
    except Warning as e:
        logger.warning(f"Warning emitted")
        error_writer.writerow([prior, later, "ConvergenceWarning", e])
    else:
        # Save results
        pred_coef = cph.params_["pred_prior"]
        pred_se = cph.standard_errors_["pred_prior"]
        pred_hr = np.exp(pred_coef)
        pred_ci_lower = np.exp(pred_coef - 1.96 * pred_se)
        pred_ci_upper = np.exp(pred_coef + 1.96 * pred_se)
        pred_pval = cph.summary.p["pred_prior"]
        pred_zval = cph.summary.z["pred_prior"]

        year_coef = cph.params_["birth_year"]
        year_se = cph.standard_errors_["birth_year"]
        year_hr = np.exp(year_coef)
        year_ci_lower = np.exp(year_coef - 1.96 * year_se)
        year_ci_upper = np.exp(year_coef + 1.96 * year_se)
        year_pval = cph.summary.p["birth_year"]
        year_zval = cph.summary.z["birth_year"]

        if not is_sex_specific:
            sex_coef = cph.params_["SEX"]
            sex_se = cph.standard_errors_["SEX"]
            sex_hr = np.exp(sex_coef)
            sex_ci_lower = np.exp(sex_coef - 1.96 * sex_se)
            sex_ci_upper = np.exp(sex_coef + 1.96 * sex_se)
            sex_pval = cph.summary.p["SEX"]
            sex_zval = cph.summary.z["SEX"]

        nsubjects = cph._n_examples
        nevents = cph.event_observed.sum()
        partial_log_likelihood = cph._log_likelihood
        concordance = cph.score_
        with np.errstate(invalid="ignore", divide="ignore"):
            sr = cph.log_likelihood_ratio_test()
            log_likelihood_ratio_test = sr.test_statistic
            log_likelihood_ndf = sr.degrees_freedom
            log_likelihood_pval = sr.p_value

    res_writer.writerow([
        prior,
        later,
        nindivs,
        median_duration,
        pred_coef,
        pred_se,
        pred_hr,
        pred_ci_lower,
        pred_ci_upper,
        pred_pval,
        pred_zval,
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
        sex_zval,
        nsubjects,
        nevents,
        partial_log_likelihood,
        concordance,
        log_likelihood_ratio_test,
        log_likelihood_ndf,
        log_likelihood_pval,
    ])


if __name__ == '__main__':
    main(
        INPUT_PAIRS,
        INPUT_PHENOTYPES,
        INPUT_DEFINITIONS,
        OUTPUT_NAME,
        OUTPUT_ERROR
    )
