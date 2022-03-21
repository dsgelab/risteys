"""Functions for computing cumulative incidence"""

import numpy as np
import pandas as pd
from risteys_pipeline.log import logger
from risteys_pipeline.config import MIN_SUBJECTS_PERSONAL_DATA
from risteys_pipeline.finregistry.survival_analysis import (
    build_cph_dataset,
    survival_analysis,
)


def cumulative_incidence(cohort, all_cases, endpoints):
    """
    Cumulative incidence with age as timescale stratified by sex

    Args:
        minimal_phenotype (DataFrame): minimal phenotype dataset
        first_events (DataFrame): first events dataset
        endpoints (DataFrame): endpoint definition dataset
b
    Returns:
        result (DataFrame): dataset with the following columns:
            endpoint: the name of the endpoint
            bch: baseline cumulative hazard by age group and sex
            params: coefficients
    """

    n_endpoints = endpoints.shape[0]
    result = pd.DataFrame(index=endpoints["endpoint"], columns=["bch", "params"])

    for i, row in endpoints.iterrows():

        outcome, female = row

        # Fit the Cox PH model
        logger.info(f"Outcome {i+1}/{n_endpoints}: {outcome}")
        if pd.isnull(female):
            df_cph = build_cph_dataset(outcome, None, cohort, all_cases)
            df_cph = df_cph.drop(columns=["birth_year"])
            cph = survival_analysis(df_cph, "age", stratify_by_sex=True)
        else:
            subcohort = cohort.loc[cohort["female"] == female]
            subcohort = subcohort.reset_index(drop=True)
            df_cph = build_cph_dataset(outcome, None, subcohort, all_cases)
            df_cph = df_cph.drop(columns=["birth_year"])
            cph = survival_analysis(df_cph, "age", drop_sex=True)

        bch = np.nan
        params = np.nan

        if cph:
            # Calculate number of events by age group
            counts = df_cph.loc[df_cph["outcome"] == 1].reset_index(drop=True)
            counts["age"] = round((counts["stop"] - counts["birth_year"]) / 10) * 10
            counts = counts.groupby("age")["outcome"].sum().reset_index()
            counts = counts.rename(columns={"outcome": "n_events"})

            # Calculate baseline cumulative hazard by age group
            bch = cph.baseline_cumulative_hazard_
            bch = bch.reset_index()
            bch = bch.rename(columns={"index": "age", 0: "male", 1: "female"})
            bch["age"] = round(bch["age"] / 10) * 10
            bch = bch.groupby("age").mean()
            bch = bch.merge(counts, on="age", how="left")
            bch = bch.loc[bch["n_events"] >= MIN_SUBJECTS_PERSONAL_DATA]
            bch = bch.drop(columns=["n_events"])
            bch = bch.set_index("age").to_dict()

            # Extract parameters
            params = cph.params_.to_dict()

        # Add data to resuls
        result.loc[outcome] = {"bch": bch, "params": params}

    return result

