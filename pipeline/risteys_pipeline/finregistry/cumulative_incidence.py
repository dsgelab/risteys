"""Functions for computing cumulative incidence"""

import pandas as pd
from risteys_pipeline.log import logger
from risteys_pipeline.config import MIN_SUBJECTS_PERSONAL_DATA
from risteys_pipeline.finregistry.survival_analysis import (
    build_cph_dataset,
    survival_analysis,
)


def cumulative_incidence(endpoint, endpoint_sex, all_cases, cohort):
    """
    Cumulative incidence with age as timescale.
    
    Stratified by sex if the endpoint is not sex-specific:
    `Surv(start_age, end_age, outcome) ~ strata(sex)`

    Sex is dropped if the endpoint is sex-specific:
    `Surv(start_age, end_age, outcome) ~ 1`

    It is assumed that sex-specific endpoints have no cases of the opposite sex.

    Args:
        endpoint (string): name of the endpoint
        endpoint_sex (string): is the endpoint sex-specific. female/male/None
        all_cases (DataFrame): dataset cases for all endpoints
        cohort (DataFrame): cohort dataset 

    Returns: 
        CIF (DataFrame): dataset with the following columns:
            endpoint: the name of the endpoint
            sex: sex (female/male)
            age: age bin
            cumulinc: cumulative incidence function
    """
    CIF = None

    df_cph = build_cph_dataset(endpoint, None, cohort, all_cases)

    if endpoint_sex:
        cph = survival_analysis(df_cph, "age", drop=["female", "birth_year"])
        sex_cols = {0: endpoint_sex}

    else:
        cph = survival_analysis(
            df_cph, "age", stratify_by_sex=True, drop=["birth_year"]
        )
        sex_cols = {0: "male", 1: "female"}

    if cph:

        # Compute cumulative incidence function
        subject = pd.DataFrame({"female": [0, 1]})
        times = range(0, 101, 1)
        S = cph.predict_survival_function(subject, times)
        CIF = 1 - S

        # Reformat the data frame
        CIF = CIF.reset_index().rename(columns={"index": "age"})
        CIF = CIF.rename(columns=sex_cols)
        CIF = pd.melt(CIF, id_vars=["age"], var_name="sex", value_name="cumulinc")
        CIF["endpoint"] = endpoint

        # Count the number of cases
        counts = df_cph.loc[df_cph["outcome"] == 1].reset_index(drop=True)
        counts["age"] = round(counts["stop"] - counts["birth_year"])
        counts["sex"] = counts["female"].replace({1: "female", 0: "male"})
        counts = counts.groupby(["age", "sex"])["outcome"].sum().reset_index()
        counts = counts.rename(columns={"outcome": "n_cases"})

        # Remove personal data
        CIF = CIF.merge(counts, how="left", on=["age", "sex"]).fillna(0)
        CIF = CIF.loc[CIF["n_cases"] >= MIN_SUBJECTS_PERSONAL_DATA]
        CIF = CIF.reset_index(drop=True)
        CIF = CIF[["endpoint", "age", "sex", "cumulinc"]]

    return CIF


if __name__ == "__main__":
    from risteys_pipeline.finregistry.load_data import load_data
    from risteys_pipeline.finregistry.survival_analysis import (
        get_cohort,
        prep_all_cases,
    )
    from risteys_pipeline.finregistry.write_data import get_output_filepath

    endpoints, minimal_phenotype, first_events = load_data()

    cohort = get_cohort(minimal_phenotype)
    all_cases = prep_all_cases(first_events, cohort)
    n_endpoints = endpoints.shape[0]

    result = []

    for i, row in endpoints.iterrows():
        endpoint = row["endpoint"]
        endpoint_sex = {True: "female", False: "male", pd.NA: None}[row["female"]]
        logger.info(f"Outcome {i+1}/{n_endpoints}: {endpoint}")

        ci = cumulative_incidence(endpoint, endpoint_sex, all_cases, cohort)
        result.append(ci)

    result = pd.concat(result, axis=0)

    output_file = get_output_filepath("cumulative_incidence", "csv")
    result.to_csv(output_file, index=False)
