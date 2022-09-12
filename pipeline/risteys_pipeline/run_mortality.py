"""Mortality analysis"""

import pandas as pd
import numpy as np

from risteys_pipeline.utils.log import logger
from risteys_pipeline.config import (
    MIN_SUBJECTS_PERSONAL_DATA,
    MIN_SUBJECTS_SURVIVAL_ANALYSIS,
)
from risteys_pipeline.survival_analysis import (
    get_cases,
    build_survival_dataset,
    get_exposed,
    set_timescale,
    survival_analysis,
)

N_DIGITS = 4

def times_without_personal_data(times):
    """
    Get times with at least `MIN_SUBJECTS_PERSONAL_DATA` persons.
    Event times are rounded to form groups.

    Args:
        times (Series): list of distinct event times (e.g. ages or follow-up durations)

    Returns:
        times (Series): event times with no personal data
    """
    times = times.round().value_counts().sort_index()
    times = times[times >= MIN_SUBJECTS_PERSONAL_DATA]

    return times.index


def exposure_to_death(endpoint, cases, exposed, cohort):
    """
    Mortality analysis for `endpoint` with exposure-to-death as a timescale
    - Kaplan-Meier estimate (Aalen-Johansen with no competing events)
    - time-on-study (exposure-to-death) as a timescale
    - only exposed persons are included
    - stratified by sex
    - buffer of 30 days between exposure and outcome

    Args:
        endpoint (str): name of the endpoint
        cases (DataFrame): cases dataset (persons who died)
        exposed (DataFrame): exposed dataset (persons with exposure endpoint)
        cohort (DataFrame): cohort for sampling controls

    Returns:
        surv (DataFrame): survival function for endpoint
    """
    logger.debug(f"{endpoint}")

    surv = None

    cohort = cohort.join(exposed, how="inner")
    cases = cases.join(exposed, how="inner")

    cohort["start"] = cohort["exposure_year"]
    cases["start"] = cases["exposure_year"]

    sexes = exposed["female"].unique()
    for sex in sexes:

        cols = ["start", "stop", "outcome", "birth_year"]
        cohort_ = cohort.loc[cohort["female"] == sex, cols]
        cases_ = cases.loc[cases["female"] == sex, cols]

        df_survival = build_survival_dataset(cases_, cohort_)
        df_survival = set_timescale(df_survival, "time-on-study")

        model = survival_analysis(df_survival, "aalen-johansen")

        if model is not None:

            logger.debug("Removing personal data")

            times = df_survival.loc[df_survival["outcome"] == 1, "stop"]
            times = times_without_personal_data(times)

            if len(times) > 0:

                if len(ages == 1):
                    ages = np.repeat(ages, 2)

                survival = 1 - model.predict(times)


    return surv


def mortality_analysis(endpoint, cases, exposed, cohort):
    """
    Mortality analysis for `endpoint`
    - Cox PH model
    - age as timescale
    - endpoint is a time-varying covariate, birth_year is a covariate
    - stratified by sex (parameters are estimated by sex)
    - buffer of 30 days between exposure and outcome

    Args:
        endpoint (str): name of the endpoint
        cases (DataFrame): cases dataset (persons who died)
        exposed (DataFrame): exposed dataset (persons with exposure endpoint)
        cohort (DataFrame): cohort for sampling controls

    Returns:
        (params, cumulative_baseline_hazard) (tuple of DataFrames):
        parameters and cumulative baseline hazard by age
    """
    logger.debug(f"{endpoint}")

    params = []
    cumulative_baseline_hazard = []
    counts = []

    exposed_cases = cases.join(exposed, how="inner")
    sexes = exposed_cases["female"].unique()

    for sex in sexes:

        exposed_cases_ = exposed_cases.loc[exposed_cases["female"] == sex]

        if exposed_cases_.shape[0] >= MIN_SUBJECTS_SURVIVAL_ANALYSIS:

            cases_ = cases.loc[cases["female"] == sex]
            cohort_ = cohort.loc[cohort["female"] == sex]

            df_survival = build_survival_dataset(cases_, cohort_, exposed)
            df_survival = set_timescale(df_survival, "age")
            df_survival = df_survival.drop(columns=["female"])

            model = survival_analysis(df_survival, "cox")

            if model is not None:

                logger.debug("Removing personal data")

                # Get cumulative baseline hazard by age
                cbh_ = model.baseline_cumulative_hazard_
                cbh_ = cbh_.reset_index().rename(columns={"index": "age"})
                cbh_["age"] = cbh_["age"].round(0)
                cbh_ = cbh_.groupby("age").mean().reset_index()
                cbh_ = cbh_.rename(columns={"baseline cumulative hazard": "baseline_cumulative_hazard"})

                # Get ages with enough data
                age_counts = (
                    df_survival.loc[df_survival["outcome"] == 1]["stop"]
                    .round()
                    .value_counts()
                    .sort_index()
                )
                ages = age_counts[age_counts >= MIN_SUBJECTS_PERSONAL_DATA]

                if len(ages) > 0:

                    # Remove personal data
                    cbh_ = cbh_.loc[cbh_["age"].isin(ages.index)].reset_index(drop=True)

                    cbh_["sex"] = {True: "female", False: "male"}[sex]
                    cbh_["endpoint"] = endpoint

                    cumulative_baseline_hazard.append(cbh_)

                cols = ["coef", "coef lower 95%", "coef upper 95%", "p"]
                params_ = model.summary[cols]
                params_ = params_.rename(
                    columns={
                        "coef lower 95%": "ci95_lower",
                        "coef upper 95%": "ci95_upper",
                        "p": "p_value",
                    }
                )

                means = df_survival[["birth_year", "exposure"]].mean()
                params_ = params_.join(means.rename("mean"))

                params_ = params_.round(N_DIGITS)
                params_["sex"] = {True: "female", False: "male"}[sex]
                params_["endpoint"] = endpoint
                params_ = params_.reset_index()

                params.append(params_)

                exposed_ = exposed.join(cohort["female"], how="inner")
                counts_ = {
                    "exposed": exposed_.loc[exposed_["female"] == sex].shape[0],
                    "exposed_cases": exposed_cases_.shape[0],
                    "sex": {True: "female", False: "male"}[sex],
                }
                counts_ = pd.DataFrame(counts_, index=[endpoint])
                counts_ = counts_.reset_index().rename(columns={"index": "endpoint"})
                counts.append(counts_)

    if cumulative_baseline_hazard:
        cumulative_baseline_hazard = pd.concat(cumulative_baseline_hazard, axis=0)

    if params:
        params = pd.concat(params, axis=0)

    if counts:
        counts = pd.concat(counts, axis=0)

    return (params, cumulative_baseline_hazard, counts)


if __name__ == "__main__":
    import pandas as pd
    from risteys_pipeline.finregistry.load_data import load_data
    from risteys_pipeline.survival_analysis import get_cohort
    from risteys_pipeline.utils.write_data import get_output_filepath
    from multiprocessing import get_context
    from functools import partial
    from tqdm import tqdm

    N_PROCESSES = 20

    endpoint_definitions, minimal_phenotype, first_events = load_data()
    endpoint_definitions = endpoint_definitions.loc[endpoint_definitions["endpoint"] != "DEATH"].reset_index(drop=True)
    n_endpoints = endpoint_definitions.shape[0]

    cohort = get_cohort(minimal_phenotype)
    mortality_cases = get_cases("death", first_events, cohort)
    get_exposed_ = partial(
        get_exposed, first_events=first_events, cohort=cohort, cases=mortality_cases
    )

    logger.info("Start multiprocessing")

    with get_context("spawn").Pool(processes=N_PROCESSES) as pool, tqdm(
        total=n_endpoints, desc="Mortality"
    ) as pbar:
        result = [
            pool.apply_async(
                mortality_analysis,
                args=(endpoint, mortality_cases, get_exposed_(endpoint), cohort,),
                callback=lambda _: pbar.update(),
            )
            for endpoint in endpoint_definitions["endpoint"]
        ]
        result = [r.get() for r in result]

    params = [x[0] for x in result if len(x[0]) > 0]
    bch = [x[1] for x in result if len(x[1]) > 0]
    counts = [x[2] for x in result if len(x[2]) > 0]

    params = pd.concat(params, axis=0, ignore_index=True)
    bch = pd.concat(bch, axis=0, ignore_index=True)
    counts = pd.concat(counts, axis=0, ignore_index=True)

    logger.info("Writing output to file")
    params_output_file = get_output_filepath("mortality_params", "csv")
    bch_output_file = get_output_filepath("mortality_baseline_cumulative_hazard", "csv")
    counts_output_file = get_output_filepath("mortality_counts", "csv")
    params.to_csv(params_output_file, index=False)
    bch.to_csv(bch_output_file, index=False)
    counts.to_csv(counts_output_file, index=False)

