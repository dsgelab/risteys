"""Functions for preprocessing FinRegistry data"""

from risteys_pipeline.log import logger
from risteys_pipeline.config import FOLLOWUP_START, FOLLOWUP_END

DAYS_IN_YEAR = 365.25
SEX_FEMALE = 1.0


def list_excluded_subjects(minimal_phenotype):
    """List subjects who should be excluded from the analyses based on the following criteria: 
        - born after the end of the follow-up
        - died before the start of the follow-up
        - missing finregistryid
        - missing sex

    Args:
        minimal_phenotype (dataframe): minimal phenotype dataset with the following columns included: 
        birth_year, death_year, finregistryid, sex

    Returns:
        excluded_subjects (list): finregistryids of the excluded subjects
    """
    born_after_followup_end = minimal_phenotype["birth_year"] >= FOLLOWUP_END
    dead_before_followup_start = minimal_phenotype["death_year"] <= FOLLOWUP_START
    id_missing = minimal_phenotype["finregistryid"].isna()
    sex_missing = minimal_phenotype["sex"].isna()
    exclude = (
        born_after_followup_end | dead_before_followup_start | id_missing | sex_missing
    )
    excluded_subjects = minimal_phenotype.loc[exclude, "finregistryid"].tolist()
    logger.info(
        f"{len(excluded_subjects)} excluded subjects (born after follow-up: {sum(born_after_followup_end)}, dead before follow-up: {sum(dead_before_followup_start)}, id missing: {sum(id_missing)}, sex missing: {sum(sex_missing)})"
    )
    return excluded_subjects


def merge_first_events_data_with_minimal_phenotype(first_events, minimal_phenotype):
    """Merge first events data with minimal phenotype"""
    first_events = first_events.merge(minimal_phenotype, how="left", on="finregistryid")
    return first_events
