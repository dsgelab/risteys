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
