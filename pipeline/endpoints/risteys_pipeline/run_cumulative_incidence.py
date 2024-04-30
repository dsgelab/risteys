"""Functions for computing cumulative incidence"""

import pandas as pd
import numpy as np
from risteys_pipeline.utils.log import logger
from risteys_pipeline.config import MIN_SUBJECTS_PERSONAL_DATA
from risteys_pipeline.survival_analysis import (
    MIN_SUBJECTS_SURVIVAL_ANALYSIS,
    add_death_as_competing_event,
    get_cases,
    build_survival_dataset,
    set_timescale,
    survival_analysis,
)

N_DECIMALS = 4


def cumulative_incidence_function(endpoint, cases, cohort):
    """
    Compute the Cumulative Incidence Function (CIF) for `endpoint`
    - Johansen-Aalen estimator
    - age as timescale
    - death as a competing event
    - stratified by sex

    Args:
        endpoint (str): name of the endpoint
        cases (DataFrame): cases dataset (persons with endpoint)
        cohort (DataFrame): cohort for sampling controls

    Returns:
        CIF (DataFrame): cumulative incidence function dataset with the following columns:
            endpoint: the name of the endpoint
            sex: female/male
            age: age bin
            cumulinc: cumulative incidence function
    """
    logger.debug(f"{endpoint}")

    CIF = []

    sexes = cases["female"].unique()

    for sex in sexes:

        cases_ = cases.loc[cases["female"] == sex]

        if cases_.shape[0] > MIN_SUBJECTS_SURVIVAL_ANALYSIS:

            cohort_ = cohort.loc[cohort["female"] == sex]
            df_survival = build_survival_dataset(cases_, cohort_)
            df_survival = add_death_as_competing_event(df_survival)
            df_survival = set_timescale(df_survival, "age")
            df_survival = df_survival.drop(columns=["female"])

            model = survival_analysis(df_survival, "aalen-johansen")

            if model is not None:

                # Get ages with enough data
                age_counts = (
                    df_survival.loc[df_survival["outcome"].values == 1]["stop"]
                    .round()
                    .value_counts()
                    .sort_index()
                )
                ages = age_counts[age_counts >= MIN_SUBJECTS_PERSONAL_DATA].index

                if len(ages) > 0:

                    # Duplicate ages of length 1 to keep the same output format
                    # The duplicate is later dropped
                    if len(ages == 1):
                        ages = np.repeat(ages, 2)

                    CIF_ = model.predict(ages).drop_duplicates()

                    # Format output
                    CIF_ = CIF_.reset_index()
                    CIF_ = CIF_.rename(columns={"index": "age", "CIF_1": "cumulinc"})
                    CIF_["cumulinc"] = CIF_["cumulinc"].round(N_DECIMALS)
                    CIF_["sex"] = {True: "female", False: "male"}[sex]

                    CIF.append(CIF_[["age", "sex", "cumulinc"]])

    if CIF:
        CIF = pd.concat(CIF, axis=0)
        CIF["endpoint"] = endpoint

    return CIF


if __name__ == "__main__":
    from risteys_pipeline.finregistry.load_data import load_data
    from risteys_pipeline.survival_analysis import get_cohort
    from risteys_pipeline.utils.write_data import get_output_filepath
    from multiprocessing import get_context
    from tqdm import tqdm

    N_PROCESSES = 20

    endpoint_definitions, minimal_phenotype, first_events = load_data()
    n_endpoints = endpoint_definitions.shape[0]

    cohort = get_cohort(minimal_phenotype)

    logger.info("Start multiprocessing")

    with get_context("spawn").Pool(processes=N_PROCESSES) as pool, tqdm(
        total=n_endpoints, desc="Computing CIF"
    ) as pbar:
        result = [
            pool.apply_async(
                cumulative_incidence_function,
                args=(endpoint, get_cases(endpoint, first_events, cohort), cohort),
                callback=lambda _: pbar.update(),
            )
            for endpoint in endpoint_definitions["endpoint"]
        ]
        result = [r.get() for r in result]

    result = [x for x in result if len(x) > 0]
    result = pd.concat(result, axis=0, ignore_index=True)

    logger.info("Writing output to file")
    output_file = get_output_filepath("cumulative_incidence", "csv")
    result.to_csv(output_file, index=False)
