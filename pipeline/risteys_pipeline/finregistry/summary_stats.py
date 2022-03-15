"""
Functions for the following summary statistics:
- key figures (number of individuals, unadjusted prevalence, mean age at first event)
- distributions: age at first event, year at first event
- cumulative incidence
"""

import numpy as np
import pandas as pd
from risteys_pipeline.log import logger
from risteys_pipeline.config import MIN_SUBJECTS_PERSONAL_DATA
from risteys_pipeline.finregistry.survival_analysis import (
    build_cph_dataset,
    survival_analysis,
)


def compute_key_figures(first_events, minimal_phenotype, index_persons=False):
    """
    Compute the following key figures for each endpoint:
        - number of individuals
        - unadjusted prevalence (%)
        - mean age at first event (years)

    The numbers are calculated for males, females, and all.

    Args:
        first_events (DataFrame): first events dataframe
        minimal_phenotype(DataFrame): minimal phenotype dataframe
        index_persons (bool): compute key figures for index persons only (True) or everyone (False)

    Returns:
        kf (DataFrame): key figures dataframe with the following columns:
        endpoint, 
        nindivs_female, nindivs_male, nindivs_all, 
        mean_age_female, mean_age_male, mean_age_all,
        prevalence_female, prevalence_male, prevalence_all
    """
    logger.info(
        "Computing key figures" + (" for index persons" if index_persons else "")
    )

    mp = minimal_phenotype.copy()
    fe = first_events.copy()

    # Only include index_persons if specified
    if index_persons:
        mp = mp.loc[mp["index_person"] == True].reset_index(drop=True)
        fe = fe.loc[fe["index_person"] == True].reset_index(drop=True)

    # Calculate the total number of individuals
    # Note: individuals for sex="unknown" is based on first events
    n_total = {
        "female": sum(mp["female"] == True),
        "male": sum(mp["female"] == False),
        "unknown": len(fe.loc[fe["sex"] == "unknown", "finregistryid"].unique()),
    }

    # Calculate key figures by endpoint and sex
    kf = (
        fe.groupby(["endpoint", "sex"])
        .agg({"finregistryid": "count", "age": "mean"})
        .rename(columns={"finregistryid": "nindivs_", "age": "mean_age_"})
        .fillna({"nindivs_": 0})
        .reset_index()
    )
    kf["prevalence_"] = kf["nindivs_"] / kf["sex"].replace(n_total)
    kf["n_endpoint"] = kf.groupby("endpoint")["nindivs_"].transform("sum")
    kf["w"] = kf["nindivs_"] / kf["n_endpoint"]

    # Calculate key figures by endpoint for all individuals
    kf_all = (
        kf.groupby("endpoint")
        .agg(
            {
                "nindivs_": "sum",
                "mean_age_": lambda x: np.average(x, weights=kf.loc[x.index, "w"]),
                "prevalence_": lambda x: np.average(x, weights=kf.loc[x.index, "w"]),
            }
        )
        .reset_index()
        .assign(sex="all")
    )

    # Drop rows with sex=unknown
    kf = kf.loc[kf["sex"] != "unknown"].reset_index(drop=True)

    # Combine the two datasets
    kf = pd.concat([kf, kf_all])

    # Drop redundant columns
    kf = kf.drop(columns=["w", "n_endpoint"])

    # Remove personal data
    cols = ["nindivs_", "mean_age_", "prevalence_"]
    kf.loc[kf["nindivs_"] < MIN_SUBJECTS_PERSONAL_DATA, cols,] = np.nan

    # Pivot and flatten hierarchical columns
    kf = kf.pivot(index="endpoint", columns="sex").reset_index()
    kf.columns = ["".join(col).strip() for col in kf.columns.values]

    return kf


def green_distribution(dist):
    """
    Aggregate bins to have no individual-level data based on `MIN_SUBJECTS_PERSONAL_DATA`.
    Values 0 < x < MIN_PERSONAL_DATA are considered individual-level data.

    Input:
        dist (DataFrame): distribution to be aggregated

    Returns:
        res (DataFrame): distribution with no individual-level data
    """

    res = []

    # Early return if the count is too low to produce non individual-level data
    if dist.sum() >= MIN_SUBJECTS_PERSONAL_DATA:

        # Initialize rolling bin lower bound and accumulated count
        interval_left = None
        acc_count = 0

        # Aggregate individual-level data up and update the interval endpoints
        for (endpoint, interval), count in dist.items():
            acc_count += count
            interval_left = interval.left if interval_left is None else interval_left
            if (acc_count == 0) | (acc_count >= MIN_SUBJECTS_PERSONAL_DATA):
                res.append(
                    {"left": interval_left, "right": interval.right, "count": acc_count}
                )
                acc_count = 0
                interval_left = None

        # If the last count was personal-level data, it was discarded in the previous loop. Fixed here.
        # The value is accumulated from right to left until it is added to a large enough bin
        if (acc_count != 0) & (acc_count < MIN_SUBJECTS_PERSONAL_DATA):
            res[-1]["count"] += acc_count
            res[-1]["right"] = interval.right
            while (res[-1]["count"] != 0) & (res[-1]["count"] < 5):
                last = res.pop()
                res[-1]["count"] += last["count"]
                res[-1]["right"] = last["right"]

    return res


def compute_distribution(first_events, column):
    """
    Compute distribution of values in the given column (age/year) for all endpoints.
    Bins are aggregated so that each bar contains at least `MIN_SUBJECTS_PERSONAL_DATA` persons.
    
    No sex-specific distributions are computed as they are currently not used.

    Args:
        first_events (DataFrame): first events dataset
        column (str): column used for the distributions; "age" or "year"

    Returns:
        res (DataFrame): distribution of values
    """

    logger.info(f"Computing distribution for {column}")

    # Add brackets
    if column == "age":
        brackets = list(range(0, 100, 10)) + [np.inf]
    elif column == "year":
        max_year = round(first_events["year"].max())
        brackets = [np.NINF] + list(range(1970, max_year, 5)) + [max_year]

    # Compute distribution
    dist = (
        first_events[["endpoint", column]]
        .assign(bin=pd.cut(first_events[column], brackets, right=False))
        .groupby(["endpoint", "bin"])
        .size()
        .sort_index()
        .groupby("endpoint")
        .apply(lambda x: green_distribution(x))
    )

    # Reshape dataframe
    res = []
    for endpoint, bins in dist.items():
        for bin in bins:
            res.append([endpoint, "all", bin["left"], bin["right"], bin["count"]])
    res = pd.DataFrame(res, columns=["endpoint", "sex", "left", "right", "count"])

    return res


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
            cph = survival_analysis(df_cph, "age", stratify_by_sex=True)
        else:
            subcohort = cohort.loc[cohort["female"] == female]
            subcohort = subcohort.reset_index(drop=True)
            df_cph = build_cph_dataset(outcome, None, subcohort, all_cases)
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
            bch = bch.loc[bch["n_events"] > MIN_SUBJECTS_PERSONAL_DATA]
            bch = bch.drop(columns=["n_events"])
            bch = bch.set_index("age").to_dict()

            # Extract parameters
            params = cph.params_.to_dict()

        # Add data to resuls
        result.loc[outcome] = {"bch": bch, "params": params}

    return result

