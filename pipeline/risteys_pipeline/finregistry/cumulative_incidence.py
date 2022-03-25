"""Functions for computing cumulative incidence"""

import pandas as pd
from risteys_pipeline.log import logger
from risteys_pipeline.config import MIN_SUBJECTS_PERSONAL_DATA
from risteys_pipeline.finregistry.survival_analysis import (
    build_survival_dataset,
    survival_analysis,
)

N_DIGITS = 4


def cumulative_incidence(endpoint, all_cases, cohort):
    """
    Cumulative incidence with age as timescale and death as a competing event.
    It is assumed that sex-specific endpoints have no cases of the opposite sex.

    Args:
        endpoint (string): name of the endpoint
        all_cases (DataFrame): dataset cases for all endpoints
        cohort (DataFrame): cohort dataset 

    Returns: 
        CIF (DataFrame): dataset with the following columns:
            endpoint: the name of the endpoint
            sex: sex (female/male)
            age: age bin
            cumulinc: cumulative incidence function

    TODO: Catch statistical warning
    TODO: Sample for sexes independently
    """

    CIF = None

    df_survival = build_survival_dataset(
        endpoint, None, cohort, all_cases, competing_events=True
    )

    if df_survival is not None:

        CIF = []
        sexes = df_survival["female"].unique()
        ages = range(0, 101, 1)

        for sex in sexes:

            # Fit the model
            df_survival_ = df_survival.loc[df_survival["female"] == sex]
            df_survival_ = df_survival_.reset_index(drop=True)
            model = survival_analysis(df_survival_, "age", competing_events=True)

            if model is not None:
                # Compute the cumulative incidence function
                CIF_ = model.predict(ages).reset_index()
                CIF_ = CIF_.rename(columns={"index": "age", "CIF_1": "cumulinc"})
                CIF_["sex"] = {True: "female", False: "male"}[sex]
                CIF_["endpoint"] = endpoint
                CIF_["cumulinc"] = CIF_["cumulinc"].round(N_DIGITS)

                # Count cases per age
                counts = (
                    df_survival.loc[
                        (df_survival["female"] == sex) & (df_survival["outcome"] == 1)
                    ]
                    .reset_index(drop=True)
                    .assign(age=lambda x: round(x["stop"] - x["birth_year"]))
                    .groupby("age")["outcome"]
                    .sum()
                    .reset_index()
                    .rename(columns={"outcome": "n_cases"})
                )

                # Remove personal data
                CIF_ = CIF_.merge(counts, how="left", on=["age"]).fillna(0)
                CIF_ = CIF_.loc[CIF_["n_cases"] >= MIN_SUBJECTS_PERSONAL_DATA]
                CIF_ = CIF_.reset_index(drop=True)

                CIF.append(CIF_[["endpoint", "age", "sex", "cumulinc"]])

        if CIF:
            CIF = pd.concat(CIF, axis=0)

    return CIF


if __name__ == "__main__":
    from risteys_pipeline.finregistry.load_data import load_data
    from risteys_pipeline.finregistry.survival_analysis import (
        get_cohort,
        prep_all_cases,
    )
    from risteys_pipeline.finregistry.write_data import get_output_filepath
    from multiprocessing import Pool
    from functools import partial
    from tqdm import tqdm

    endpoints, minimal_phenotype, first_events = load_data()

    endpoints = endpoints.loc[endpoints["endpoint"] != "DEATH"].reset_index(drop=True)
    n_endpoints = endpoints.shape[0]

    cohort = get_cohort(minimal_phenotype)
    all_cases = prep_all_cases(first_events, cohort)

    logger.info("Start multiprocessing")

    partial_ci = partial(cumulative_incidence, all_cases=all_cases, cohort=cohort)
    args_iter = iter(endpoints["endpoint"])

    N_PROCESSES = 10
    with Pool(processes=N_PROCESSES) as pool:
        result = list(
            tqdm(
                pool.imap_unordered(
                    partial_ci, args_iter, chunksize=n_endpoints // N_PROCESSES
                ),
                total=n_endpoints,
            )
        )

    result = [x for x in result if x is not None] # remove Nones
    result = [x for x in result if len(x) > 0] # remove empty lists
    result = pd.concat(result, axis=0, ignore_index=True)

    logger.info("Writing output to file")
    output_file = get_output_filepath("cumulative_incidence", "csv")
    result.to_csv(output_file, index=False)
