"""Functions for summary statistics"""

import numpy as np
from risteys_pipeline.log import logger
from risteys_pipeline.config import (
    FOLLOWUP_START,
    FOLLOWUP_END,
    MIN_SUBJECTS_PERSONAL_DATA,
)

SEX_FEMALE = 1.0
SEX_MALE = 0.0


def compute_key_figures(first_events):
    """Compute the following key figures for each endpoint:
        - number of individuals
        - unadjusted prevalence (%)
        - mean age at first event (years)

    The numbers are calculated for men, women, and all separately.
    Note: the total number of individuals is calculated from first_events and not minimal_phenotype.

    Args:
        first_events (DataFrame): preprocessed first events dataframe

    Returns:
        key_figures (DataFrame): key figures dataframe with the following columns:
        endpoint, 
        nindivs_female, nindivs_male, nindivs_all, 
        mean_age_female, mean_age_male, mean_age_all,
        prevalence_female, prevalence_male, prevalence_all
    """

    # Compute number of individuals and mean age
    key_figures = (
        first_events.replace(
            {"sex": {SEX_FEMALE: "female", SEX_MALE: "male", np.nan: "unknown"}}
        )
        .groupby(["endpoint", "sex"])
        .agg({"finregistryid": "count", "age": "mean"})
        .rename(columns={"finregistryid": "nindivs_", "age": "mean_age_"})
        .fillna({"nindivs_": 0})
        .reset_index()
        .pivot(index="endpoint", columns="sex")
        .reset_index()
    )

    # Flatten hierarchical columns
    key_figures.columns = ["".join(col).strip() for col in key_figures.columns.values]

    # Calculte the total number of individuals
    n_all = first_events["finregistryid"].unique().shape[0]
    n_females = (
        first_events.loc[first_events["sex"] == SEX_FEMALE, "finregistryid"]
        .unique()
        .shape[0]
    )
    n_males = (
        first_events.loc[first_events["sex"] == SEX_MALE, "finregistryid"]
        .unique()
        .shape[0]
    )

    # Calculate nindivs_all
    key_figures["nindivs_all"] = key_figures[
        ["nindivs_female", "nindivs_male", "nindivs_unknown"]
    ].sum(axis=1, skipna=True)

    # Calculate prevalence
    key_figures["prevalence_all"] = key_figures["nindivs_all"] / n_all
    key_figures["prevalence_female"] = key_figures["nindivs_female"] / n_females
    key_figures["prevalence_male"] = key_figures["nindivs_male"] / n_males

    # Calculate the mean age for all individuals as a weighted mean
    key_figures["mean_age_all"] = (
        key_figures["nindivs_female"] * key_figures["mean_age_female"]
        + key_figures["nindivs_male"] * key_figures["mean_age_male"]
        + key_figures["nindivs_unknown"] * key_figures["mean_age_unknown"]
    ) / key_figures["nindivs_all"]

    # Drop redundant columns
    key_figures = key_figures.drop(columns=["nindivs_unknown", "mean_age_unknown"])

    # Drop personal data
    for group in ["female", "male", "all"]:
        cols = [x + group for x in ["nindivs_", "mean_age_", "prevalence_"]]
        indx = key_figures["nindivs_" + group] <= MIN_SUBJECTS_PERSONAL_DATA
        key_figures.loc[indx, cols] = np.nan

    return key_figures
