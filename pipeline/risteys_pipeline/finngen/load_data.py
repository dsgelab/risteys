import csv
from pathlib import Path

import numpy as np
import pandas as pd

from risteys_pipeline.utils.log import logger
from risteys_pipeline.utils.utils import log_if_diff


def load_data(
        definitions_path,
        minimal_phenotype_path,
        covariates_path,
        densified_first_events_path,
        detailed_longitudinal_path
):
    """Load input data from original files to pandas DataFrames.

    The resulting DataFrames are compliant with the format used for
    the next pipeline steps.
    """
    df_definitions = load_endpoint_definitions(definitions_path)
    df_fgid_covariates = load_fgid_covariates(covariates_path)
    df_minimal_phenotype = load_minimal_phenotype_data(
        minimal_phenotype_path,
        densified_first_events_path,
        detailed_longitudinal_path,
        df_fgid_covariates
    )
    df_first_events = load_first_events_data(
        densified_first_events_path,
        df_definitions,
        df_minimal_phenotype,
        df_fgid_covariates
    )

    logger.info("Done loading data")
    return (
        df_definitions,
        df_minimal_phenotype,
        df_first_events
    )


def load_endpoint_definitions(definitions_path):
    """Load and validate the endpoint definition file.

    The input file must have information about core-endpoint status.
    """
    logger.info("Loading endpoint definitions")
    df = pd.read_csv(
        definitions_path,
        usecols=["NAME", "SEX"],
        dtype={
            "NAME": str,
            # SEX values are "1", "2" or "". They look like numbers
            # but they are more akin to categorical variable, we don't
            # do math on them. So we store them as strings.
            "SEX": str,
        }
    )

    # Input encoding for the SEX column
    sex_male = "1"
    sex_female = "2"

    # Input validation
    sex_values = df.SEX.unique()
    assert set(sex_values).issubset(set([sex_male, sex_female, np.nan]))

    # Set "female" to:
    # - True for female-based endpoints,
    # - False for male-based endpoints,
    # - NA for non-sex-specific endpoints.
    df["female"] = np.nan
    df.loc[df.SEX == sex_female, "female"] = True
    df.loc[df.SEX == sex_male, "female"] = False

    # Reshape output dataframe
    df = df.rename(columns={"NAME": "endpoint"})
    df = df.drop(columns=["SEX"])

    return df


def load_fgid_covariates(covariates_path):
    """Load and validate the input covariates file.

    This file is the output of the genotype QC analysis and is used to
    discard some individuals from the pipeline.
    """
    logger.info("Loading covariates file")
    df_cov = pd.read_csv(
        covariates_path,
        usecols=["FINNGENID"],
        dialect=csv.excel_tab
    )

    # Input validation
    assert df_cov.loc[df_cov.FINNGENID.isna(), :].shape[0] == 0

    return df_cov


def load_minimal_phenotype_data(
        minimal_phenotype_path,
        dense_fevents_path,
        detailed_longit_path,
        df_fgid_covariates
):
    """Load and validate the minimal phenotype data.

    Multiple input files are needed as not all the information is in
    the FinnGen minimal phenotype file. In particular the following
    information is taken elsewhere:
    - birth year: from the detailed longitudinal data
    - death age: from the endpoint first-event data
    """
    logger.info("Loading minimal phenotype data")

    # Load the data to get necessary info
    df_sex = pd.read_csv(
        minimal_phenotype_path,
        usecols=["FINNGENID", "SEX"],
        dialect=csv.excel_tab,
    )

    # Input validation
    sex_values = df_sex.SEX.unique()
    assert set(sex_values).issubset(set(["female", "male", np.nan]))

    # Only keep individuals that are in the covariates file
    with log_if_diff("persons in min.pheno (fgid cov. filtering)", lambda: df_sex.FINNGENID.shape[0]):
        df_sex = df_sex.loc[df_sex.FINNGENID.isin(df_fgid_covariates.FINNGENID), :]

    # Get birth and death info
    df_birth_year = get_birth_year(detailed_longit_path, df_fgid_covariates)
    df_death_age = get_death_age(dense_fevents_path, df_fgid_covariates)

    # Combine sex & birth year info
    df_out = df_sex.merge(df_birth_year, on="FINNGENID", how="outer")

    n_missing_sex = df_out.loc[df_out.SEX.isna(), :].shape[0]
    if n_missing_sex != 0:
        logger.warning(f"Keeping {n_missing_sex} persons without sex info")

    n_missing_birth = df_out.loc[df_out.birth_year.isna(), :].shape[0]
    if n_missing_birth != 0:
        logger.warning(f"Dropping {n_missing_birth} persons without birth year info")
        df_out = df_out.loc[~df_out.birth_year.isna(), :]

    # Combine with death info
    df_out = df_out.merge(df_death_age, on="FINNGENID", how="outer")

    # Derive output columns
    df_out["death_year"] = df_out.birth_year + df_out.death_age

    df_out["index_person"] = True

    df_out["female"] = df_out.SEX == "female"

    # Reshape output to be compliant with the pipeline
    df_out = df_out.rename(columns={"FINNGENID": "personid"})
    df_out = df_out.drop(columns=["death_age", "SEX"])

    return df_out


def get_birth_year(detailed_longit_path, df_fgid_covariates):
    """Derive the birth year of each FinnGen participant from longitudinal data"""
    logger.debug("Getting birth year for all individuals using detailed longitudinal data")

    days_in_year = 365.25
    months_in_year = 12

    df = pd.read_csv(
        detailed_longit_path,
        usecols=["FINNGENID", "APPROX_EVENT_DAY", "EVENT_AGE"],
        parse_dates=["APPROX_EVENT_DAY"],
        dialect=csv.excel_tab,
    )

    # Input validation
    n_nan_event_day = df.loc[df.APPROX_EVENT_DAY.isna(), :].shape[0]
    assert n_nan_event_day == 0
    n_nan_event_age = df.loc[df.EVENT_AGE.isna(), :].shape[0]
    assert n_nan_event_age == 0

    # Only keep individuals that are in the covariates file
    with log_if_diff("persons to get birth year on (fgid cov. filtering)", lambda: df.FINNGENID.unique().shape[0]):
        df = df.loc[df.FINNGENID.isin(df_fgid_covariates.FINNGENID), :]

    # Convert EVENT_AGE to pandas Timedelta
    deltas = pd.to_timedelta(
        # Pandas Timedelta doesn't support year as unit, so we use a homemade good enough conversion
        df.EVENT_AGE * days_in_year,
        unit='day'
    )
    df["birth_datetimes"] = df.APPROX_EVENT_DAY - deltas

    # Convert to float year
    approx_birth_dates = df.groupby("FINNGENID").birth_datetimes.mean()
    approx_birth_dates = (
        approx_birth_dates.dt.year
        + approx_birth_dates.dt.month / months_in_year
        + approx_birth_dates.dt.day / days_in_year
    )
    approx_birth_dates = approx_birth_dates.round(decimals=2)

    out = approx_birth_dates.reset_index().rename(
        columns={"birth_datetimes": "birth_year"}
    )
    return out


def get_death_age(dense_fevents_path, df_fgid_covariates):
    """Get the death age of individuals from the DEATH endpoint"""
    logger.debug("Getting death age for all individuals using densified first-events data")
    df = pd.read_feather(dense_fevents_path)

    df["death_age"] = np.nan
    df.loc[df.ENDPOINT == "DEATH", "death_age"] = df.loc[df.ENDPOINT == "DEATH", "AGE"]

    # Only keep individuals that are in the covariates file
    with log_if_diff("persons to get death age (fgid cov. filtering)", lambda: df.FINNGENID.unique().shape[0]):
        df = df.loc[df.FINNGENID.isin(df_fgid_covariates.FINNGENID), :]

    out = (
        df
        .groupby("FINNGENID")
        .first("death_age")
        .death_age
        .reset_index()
    )
    return out


def load_first_events_data(
        dense_fevents_path,
        df_definitions,
        df_minimal_phenotype,
        df_fgid_covariates
):
    """Load and validate the densified endpoint first-events file"""
    logger.info("Loading first-events data")
    df_fevents = pd.read_feather(dense_fevents_path)

    # Only keep individuals that are in the covariates file
    with log_if_diff(
            "persons in first-events (fgid cov. filtering)",
            lambda: df_fevents.FINNGENID.unique().shape[0]
    ):
        df_fevents = df_fevents.loc[df_fevents.FINNGENID.isin(df_fgid_covariates.FINNGENID), :]

    # Reshape dataframe to be compliant with the pipeline
    df_fevents = df_fevents.drop(columns=[
        "CONTROL_CASE_EXCL",
        "NEVT",
        "YEAR"  # we will compute the year more accuratyle based on birth_year + age at onset of endpoint
    ])
    df_fevents = df_fevents.rename(columns={
        "FINNGENID": "personid",
        "ENDPOINT": "endpoint",
        "AGE": "age",
    })

    # In FinnGen there is no concept of index person, so we mark all as being index persons
    df_fevents["index_person"] = True

    # Remove endpoints that we will not study
    with log_if_diff("endpoints (subsetting)", lambda: df_fevents.endpoint.unique().shape[0]):
        df_fevents = df_fevents.loc[df_fevents.endpoint.isin(df_definitions.endpoint), :]

    # Add birth, death, and sex info
    with log_if_diff("events (merging w/ min.pheno)", lambda: df_fevents.shape[0]), log_if_diff("persons (merging w/ min.pheno)", lambda: df_fevents.personid.unique().shape[0]):
        df_fevents = df_fevents.merge(
            df_minimal_phenotype.loc[:, ["personid", "birth_year", "death_year", "female"]],
            on="personid",
            how="left"
        )

    # Compute more accurate year of endpoint onset
    df_fevents["year"] = df_fevents.birth_year + df_fevents.age

    return df_fevents


if __name__ == '__main__':
    from argparse import ArgumentParser
    from pathlib import Path

    parser = ArgumentParser()
    parser.add_argument(
        "-e", "--input-endpoint-definitions",
        help="definition file for endpoints (with and without control) and core status (TSV)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-m", "--input-minimal-phenotype",
        help="minimal phenotype file (TSV or gzipped-TSV)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-c", "--input-covariates",
        help="analysis covariates file (TSV or gzipped-TSV)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-f", "--input-densified-first-events",
        help="densified version of the endpoint first-events file (Feather)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-d", "--input-detailed-longitudinal",
        help="detailed longitudinal data file (TSV or gzipped-TSV)",
        required=True,
        type=Path
    )

    args = parser.parse_args()

    load_data(
        args.input_endpoint_definitions,
        args.input_minimal_phenotype,
        args.input_covariates,
        args.input_densified_first_events,
        args.input_detailed_longitudinal
    )
