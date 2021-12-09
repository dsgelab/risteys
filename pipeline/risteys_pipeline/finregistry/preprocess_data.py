"""Functions for preprocessing FinRegistry data"""

import pandas as pd
from risteys_pipeline.log import logger


def preprocess_endpoints_data(df):
    """Applies the following preprocessing steps to endpoints data: 
        - lowercase column names
        - exclude omitted endpoints and drop the "omit" column
    """
    df.columns = df.columns.lower()
    df = df[df["omit"].isnull()].drop(columns=["omit"])
    return df


def preprocess_first_events_data(df):
    """Applies the following preprocessing steps to first events data: 
        - lowercase columns names
        - drop duplicated rows
        - TODO: exclude subjects who died before the start of the follow-up
        - TODO: exclude subjects who were born after the end of the study
    """
    df.columns = df.columns.lower()
    df = df.drop_duplicates()
    return df
