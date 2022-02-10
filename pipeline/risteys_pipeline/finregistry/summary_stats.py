"""
Functions for the following summary statistics:
- key figures (number of individuals, unadjusted prevalence, mean age at first event)
- distributions: age at first event, year at first event
"""

import numpy as np
import pandas as pd
from risteys_pipeline.log import logger
from risteys_pipeline.config import MIN_SUBJECTS_PERSONAL_DATA


def compute_key_figures(first_events, minimal_phenotype):
    """
    Compute the following key figures for each endpoint:
        - number of individuals
        - unadjusted prevalence (%)
        - mean age at first event (years)

    The numbers are calculated for males, females, and all.

    Args:
        first_events (DataFrame): first events dataframe
        minimal_phenotype(DataFrame): minimal phenotype dataframe

    Returns:
        key_figures (DataFrame): key figures dataframe with the following columns:
        endpoint, 
        nindivs_female, nindivs_male, nindivs_all, 
        mean_age_female, mean_age_male, mean_age_all,
        prevalence_female, prevalence_male, prevalence_all
    """
    # Calculate the total number of individuals
    # Note: individuals for sex="unknown" is based on first events
    n_total = {
        "female": sum(minimal_phenotype["female"]),
        "male": sum(~minimal_phenotype["female"]),
        "unknown": sum(first_events["sex"] == "unknown"),
    }

    # Calculate key figures by endpoint and sex
    key_figures = (
        first_events.groupby(["endpoint", "sex"])
        .agg({"finregistryid": "count", "age": "mean"})
        .rename(columns={"finregistryid": "nindivs_", "age": "mean_age_"})
        .fillna({"nindivs_": 0})
        .reset_index()
    )
    key_figures["n_total"] = key_figures["sex"].replace(n_total)
    key_figures["prevalence_"] = key_figures["nindivs_"] / key_figures["n_total"]
    key_figures["weight"] = key_figures["n_total"] / sum(n_total.values())

    # Calculate key figures by endpoint for all individuals
    key_figures_all = (
        key_figures.groupby("endpoint")
        .agg(
            {
                "nindivs_": "sum",
                "mean_age_": lambda x: np.average(
                    x, weights=key_figures.loc[x.index, "weight"]
                ),
                "prevalence_": lambda x: np.average(
                    x, weights=key_figures.loc[x.index, "weight"]
                ),
            }
        )
        .reset_index()
        .assign(sex="all")
    )

    # Drop rows with sex=unknown
    key_figures = key_figures.loc[key_figures["sex"] != "unknown"]
    key_figures = key_figures.reset_index(drop=True)

    # Combine the two datasets
    key_figures = pd.concat([key_figures, key_figures_all])

    # Drop redundant columns
    key_figures = key_figures.drop(columns=["weight", "n_total"])

    # Remove personal data
    indx = key_figures["nindivs_"] <= MIN_SUBJECTS_PERSONAL_DATA
    cols = ["nindivs_", "mean_age_", "prevalence_"]
    key_figures.loc[indx, cols] = np.nan

    # Pivot and flatten hierarchical columns
    key_figures = key_figures.pivot(index="endpoint", columns="sex").reset_index()
    key_figures.columns = ["".join(col).strip() for col in key_figures.columns.values]

    return key_figures
