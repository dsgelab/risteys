"""Functions for sampling the data for survival analyses"""

import pandas as pd
from risteys_pipeline.utils.log import logger

DAYS_IN_YEAR = 365.25


def calculate_sampling_weight(sample_ids, total_ids):
    """
    Calculate sampling weights. 
    Sampling weights are used to account for the (stratified) case-control sampling.

    Args:
        sample_ids (list): person IDs in the sample
        total_ids (list): all person IDs used for sampling

    Returns: 
        weight (float): sampling weight
    """
    weight = 1 / (len(sample_ids) / len(total_ids))

    return weight


def sample_persons(df, n_persons):
    """
    Helper function for sampling persons from a dataframe.

    Args:
        df (DataFrame): sampling dataframe
        n_persons (int): number of persons to sample

    Returns:
        df_sample (DataFrame): sample of `df` with sampling weight
    """
    n_persons = min(n_persons, df.shape[0])
    df_sample = df.sample(n=round(n_persons))
    df_sample["weight"] = calculate_sampling_weight(df_sample.index, df.index)

    return df_sample


def sample_controls(cohort, n_controls, cases, exposed=None):
    """
    Sample controls, i.e. the subcohort, from the full cohort

    Sampling is stratified by exposure, if present.
    Cases are excluded from the subcohort.
    
    Args: 
        cohort (DataFrame): cohort dataset, output of get_cohort()
        n_controls (num): number of controls to sample
        cases (DataFrame): cases dataset (persons with outcome endpoint)
        exposed (DataFrame): exposed dataset (persons with exposure endpoint)

    Returns:
        controls (DataFrame): controls sampled from the cohort with sampling weight
    
    """

    # Exclude cases
    subcohort = cohort.loc[~cohort.index.isin(cases.index)]

    if exposed is not None:

        subcohort = subcohort.join(exposed["exposure"], how="left").fillna({"exposure": 0})

        subcohort_exposed = subcohort.loc[subcohort["exposure"] == 1]
        subcohort_exposed = subcohort_exposed.drop(columns=["exposure"])

        subcohort_unexposed = subcohort.loc[subcohort["exposure"] == 0]
        subcohort_unexposed = subcohort_unexposed.drop(columns=["exposure"])

        n_per_strata = round(n_controls / 2)
        subcohort_exposed_sample = sample_persons(subcohort_exposed, n_per_strata)
        subcohort_unexposed_sample = sample_persons(subcohort_unexposed, n_per_strata)

        controls = pd.concat([subcohort_exposed_sample, subcohort_unexposed_sample])

    else:

        controls = sample_persons(subcohort, n_controls)

    logger.debug(f"{controls.shape[0]} controls sampled")

    return controls


def sample_cases(cases, n_cases, exposed=None):
    """
    Sample cases.

    Sampling is stratified by exposure, if present.

    Args:
        cases (DataFrame): cases dataset (persons with outcome endpoint)
        n_cases (int): number of cases to sample
        exposed (DataFrame): exposed dataset (persons with exposure endpoint)

    Returns:
        cases_sample (DataFrame): sample of cases with sampling weight
    """

    if exposed is not None:

        cases = cases.join(exposed["exposure"], how="left").fillna({"exposure": 0})
        
        cases_exposed = cases.loc[cases["exposure"] == 1]
        cases_exposed = cases_exposed.drop(columns=["exposure"])
        cases_unexposed = cases.loc[cases["exposure"] == 0]
        cases_unexposed = cases_unexposed.drop(columns=["exposure"])


        n_per_strata = round(n_cases / 2)
        cases_exposed_sample = sample_persons(cases_exposed, n_per_strata)
        cases_unexposed_sample = sample_persons(cases_unexposed, n_per_strata)

        cases_sample = pd.concat([cases_exposed_sample, cases_unexposed_sample])

    else:
        cases_sample = sample_persons(cases, n_cases)

    logger.debug(f"{cases_sample.shape[0]} cases sampled")

    return cases_sample

