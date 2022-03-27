"""Functions for survival analysis"""

import pandas as pd
import numpy as np
from lifelines import CoxPHFitter, AalenJohansenFitter
from lifelines.utils import ConvergenceError
from lifelines.utils import add_covariate_to_timeline
from risteys_pipeline.log import logger
from risteys_pipeline.config import (
    FOLLOWUP_END,
    FOLLOWUP_START,
    MIN_SUBJECTS_PERSONAL_DATA,
)
from risteys_pipeline.finregistry.sample import (
    sample_cases,
    sample_controls,
    calculate_case_cohort_weights,
)

N_CASES = 25_000
CONTROLS_PER_CASE = 1.5
MIN_SUBJECTS_SURVIVAL_ANALYSIS = 50
DAYS_IN_YEAR = 365.25


def get_cohort(minimal_phenotype):
    """
    Get cohort dataset with the following eligibility criteria:
        - born before the end of the follow-up
        - either not dead or died after the start of the follow-up
        - sex information is not missing

    Args:
        minimal_phenotype (DataFrame): minimal phenotype dataset

    Returns:
        cohort (DataFrame): cohort dataset with the following columns:
        personid, birth_year, female, start, stop, outcome
    """
    logger.info("Building the cohort")
    cols = ["personid", "birth_year", "death_year", "female"]
    cohort = minimal_phenotype[cols]

    born_before_fu_end = cohort["birth_year"] <= FOLLOWUP_END
    not_dead = minimal_phenotype["death_year"].isna()
    died_after_fu_start = minimal_phenotype["death_year"] >= FOLLOWUP_START
    inside_timeframe = born_before_fu_end & (not_dead | died_after_fu_start)
    cohort = cohort.loc[inside_timeframe]

    cohort = cohort.loc[~cohort["female"].isna()]

    cohort["start"] = np.maximum(cohort["birth_year"], FOLLOWUP_START)
    cohort["stop"] = np.minimum(cohort["death_year"].fillna(np.Inf), FOLLOWUP_END)

    cohort["outcome"] = 0

    cohort = cohort.drop(columns=["death_year"])

    return cohort


def prep_all_cases(first_events, cohort):
    """
    Prep all cases for survival analysis
    - drop endpoints outside study timeframe
    - drop IDs not included in the cohort
    
    Args:
        first_events (DataFrame): first events dataset
        cohort (DataFrame): cohort dataset, output of get_cohort()

    Returns:
        all_cases (DataFrame): dataset with cases for all endpoints
    """
    logger.info("Prepping all cases")
    all_cases = first_events.copy()

    inside_timeframe = (all_cases["birth_year"] + all_cases["age"]).between(
        FOLLOWUP_START, FOLLOWUP_END
    )
    all_cases = all_cases.loc[inside_timeframe].reset_index(drop=True)

    cohortids = cohort["personid"]
    all_cases = all_cases.merge(cohortids, how="right", on="personid")
    all_cases = all_cases.reset_index(drop=True)

    return all_cases


def get_exposed(exposure, all_cases, df_survival):
    """
    Get exposed subjects within `df_survival`. Exposures after outcome are excluded.
    
    Args:
        exposure (str): name of the exposure 
        all_cases (DataFrame): cases for all endpoints
        df_survival (DataFrame): survival dataset

    Returns:
        exposed (DataFrame): dataset of exposed persons
    """
    # Get exposed persons
    cols = ["personid", "birth_year", "year"]
    exposed = all_cases.loc[all_cases["endpoint"] == exposure, cols]
    exposed = exposed.reset_index(drop=True)

    # Only include persons in df_survival (right join) & add column `stop` for the next step
    cols = ["personid", "stop"]
    exposed = exposed.merge(df_survival[cols], how="right", on="personid")

    # Exclude exposures after outcome
    # year: exposure year
    # stop: min(outcome year, death year, end of followup)
    exposed = exposed.loc[exposed["stop"] > exposed["year"]]
    exposed = exposed.reset_index(drop=True)

    # The dataset only includes exposed persons
    exposed["exposure"] = 1

    exposed = exposed.rename(columns={"year": "duration"})
    exposed = exposed[["personid", "duration", "exposure"]]

    logger.debug(f"{exposure}: {exposed.shape[0]} exposed persons found")

    return exposed


def add_exposure(exposed, df_survival, buffer=30):
    """
    Add exposure to the df_survival dataset.
    Persons exposed within the buffer time are excluded from the dataset.

    Args:
        exposed (DataFrame): exposed persons
        df_survival (DataFrame): survival dataset
        buffer (int): number of days required between exposure and outcome

    Returns:
        df_survival (DataFrame): survival dataset with column `exposure` added.
    """
    # Add unique person IDs
    # Due to case-cohort sampling, the same person may appear twice in the dataset
    df_survival["personid_unique"] = (
        df_survival["personid"] + "_" + df_survival["outcome"].map(str)
    )
    exposed = exposed.merge(
        df_survival[["personid", "personid_unique"]], how="left", on="personid",
    )
    df_survival = df_survival.drop(columns={"personid"})
    exposed = exposed.drop(columns={"personid"})

    # Add exposure to the dataset
    # df_survival = add_covariate_to_timeline(
    #     df_survival,
    #     exposed,
    #     id_col="personid_unique",
    #     duration_col="duration",
    #     event_col="outcome",
    # ).fillna({"exposure": 0})

    # Add exposure to the dataset
    df_survival = df_survival.merge(exposed, how="left", on="personid_unique")
    df_survival = df_survival.fillna(value={"exposure": 0})
    indx_exposed = df_survival["exposure"] == 1

    # Get rows for the latter part of the exposure
    temp = df_survival[indx_exposed].reset_index(drop=True)
    temp["start"] = temp["duration"]
    temp["exposure"] = 1

    # Rows for the first part of the exposure
    df_survival.loc[indx_exposed, "stop"] = df_survival.loc[indx_exposed, "duration"]
    df_survival.loc[indx_exposed, "exposure"] = 0
    df_survival.loc[indx_exposed, "outcome"] = 0

    # Combine the data
    df_survival = pd.concat([df_survival, temp], axis=0, ignore_index=True)
    df_survival = df_survival.reset_index(drop=True)

    # Remote duration columns
    df_survival = df_survival.drop(columns=["duration"])

    # Rename unique personid to personid
    df_survival = df_survival.rename(columns={"personid_unique": "personid"})

    # Fix outcome data type
    df_survival["outcome"] = df_survival["outcome"].astype(int)

    # Drop persons exposed during buffer
    exposed_during_buffer = np.where(
        (df_survival["exposure"] == 1)
        & (df_survival["outcome"] == 1)
        & ((df_survival["stop"] - df_survival["start"]) <= (buffer / DAYS_IN_YEAR))
    )
    persons_to_exclude = df_survival.loc[exposed_during_buffer, "personid"].unique()
    df_survival = df_survival.loc[~df_survival["personid"].isin(persons_to_exclude)]

    # Exclude rows where start == stop
    df_survival = df_survival.loc[df_survival["start"] < df_survival["stop"]]
    df_survival = df_survival.reset_index(drop=True)

    return df_survival


def add_competing_events(df_survival):
    """
    Add death as a competing event to the dataset.
    Competing events are denoted with value 2 in the `outcome` column.

    Args: 
        df_survival (DataFrame): survival dataset

    Returns:
        df_survival (DataFrame): input dataset with competing events added
    """
    df_survival.loc[
        (df_survival["stop"] < FOLLOWUP_END) & (df_survival["outcome"] == 0), "outcome"
    ] = 2

    return df_survival


def build_survival_dataset(
    outcome, exposure, cohort, all_cases, competing_events=False
):
    """
    Build a dataset for fitting a Cox PH model.
    Exposure is included as a time-varying covariate if present.

    Args:
        outcome (str): outcome endpoint 
        exposure (str): exposure endpoint (None if there's no exposure)
        cohort (DataFrame): cohort for sampling controls 
        all_cases (DataFrame): cases for all endpoints
        competing_events (bool): is death treated as a competing event

    Returns:
        df_survival (DataFrame): dataset with the following columns:
        personid, start (year), stop (year), exposure, outcome, birth_year, female, weight
    """

    cases, caseids_total = sample_cases(all_cases, outcome, n_cases=N_CASES)
    n_cases = cases.shape[0]

    n_exposed = np.Inf
    if exposure is not None:
        outcome_years = cases[["personid", "stop"]].rename(
            columns={"stop": "outcome_year"}
        )
        exposed = get_exposed(all_cases, exposure, outcome_years)
        n_exposed = exposed.shape[0]

    df_survival = None

    if (n_cases > MIN_SUBJECTS_PERSONAL_DATA) & (
        n_exposed > MIN_SUBJECTS_PERSONAL_DATA
    ):

        controls = sample_controls(cohort, round(CONTROLS_PER_CASE * n_cases))

        weight_cases, weight_controls = calculate_case_cohort_weights(
            caseids_total, cohort["personid"], cases["personid"], controls["personid"],
        )
        cases["weight"] = weight_cases
        controls["weight"] = weight_controls

        df_survival = pd.concat([cases, controls])
        df_survival = df_survival.reset_index(drop=True)

        if competing_events:
            df_survival = add_competing_events(df_survival)

        if exposure is not None:
            df_survival = add_exposure(exposed, df_survival)

        # TODO: probably not a good place for these
        df_survival["outcome"] = df_survival["outcome"].astype(int)
        df_survival["female"] = df_survival["female"].astype(int)

        # TODO: probably not needed
        df_survival = df_survival.drop(columns=["death_year"])

        df_survival = df_survival.loc[df_survival["start"] < df_survival["stop"]]
        df_survival = df_survival.reset_index(drop=True)

    return df_survival


def check_min_number_of_subjects(df_survival):
    """
    Check that the requirement for the minimum number of subjects is met.
    The minimum number of subjects for the survival analysis cannot bypass the 
    minimum person requirement of personal data usage.

    Args:
        df_survival (DataFrame): output of build_survival_dataset

    Returns:
        check (bool): True if there's enough subjects, otherwise False
    """
    min_subjects = max(MIN_SUBJECTS_SURVIVAL_ANALYSIS, MIN_SUBJECTS_PERSONAL_DATA)
    if "exposure" in df_survival.columns:
        tbl = pd.crosstab(
            df_survival["outcome"],
            df_survival["exposure"],
            values=df_survival["personid"],
            aggfunc=pd.Series.nunique,
        )
    else:
        tbl = df_survival.groupby("outcome")["personid"].nunique()
    check = tbl.values.min() > min_subjects
    return check


def survival_analysis(
    df_survival,
    timescale="time-on-study",
    drop=None,
    stratify_by_sex=False,
    competing_events=False,
):
    """
    Fit a survival model (CoxPH or Aalen-Johanssen) to the data. 
    The model is only fitted if the requirement for the minimum number of participants is met.

    Args: 
        df_survival (DataFrame): output of build_survival_dataset()
        timescale (str): "time-on-study" (default) or "age"
        drop (list of str, optional): covariates to drop
        stratify_by_age (bool, optional): should the analysis be stratified by sex
        competing_events (bool, optional): should a competing events model be used

    Returns: 
        model (object): fitted survival model. None if there's not enough subjects.
    """

    model = None

    if df_survival is not None:

        check = check_min_number_of_subjects(df_survival)

        if not check:
            logger.debug("Not enough subjects")
            model = None
        else:
            df_timescale = df_survival.copy()

            # Set timescale
            if timescale == "time-on-study":
                df_timescale["stop"] = df_timescale["stop"] - df_timescale["start"]
                df_timescale = df_timescale.drop(columns=["start"])
                entry_col = None
            elif timescale == "age":
                df_timescale["start"] = (
                    df_timescale["start"] - df_timescale["birth_year"]
                )
                df_timescale["stop"] = df_timescale["stop"] - df_timescale["birth_year"]
                entry_col = "start"

            # Drop covariates if specified
            if drop:
                df_timescale = df_timescale.drop(columns=drop)

            # Set strata if specified
            strata = ["female"] if stratify_by_sex == True else None

            # Drop personid
            df_timescale = df_timescale.drop(columns=["personid"])

            # Fit the model
            if competing_events:
                logger.debug("Fitting the Aalen-Johansen model")
                model = AalenJohansenFitter(calculate_variance=False)
                entry = df_timescale[entry_col] if entry_col else None
                try:
                    model.fit(
                        durations=df_timescale["stop"],
                        event_observed=df_timescale["outcome"],
                        event_of_interest=1,
                        entry=entry,
                        weights=df_timescale["weight"],
                    )
                except ConvergenceError:
                    model = None
            else:
                logger.debug("Fitting the Cox PH model")
                model = CoxPHFitter()
                try:
                    model.fit(
                        df_timescale,
                        entry_col=entry_col,
                        duration_col="stop",
                        event_col="outcome",
                        strata=strata,
                        weights_col="weight",
                        robust=True,
                    )
                except ConvergenceError:
                    model = None

    return model
