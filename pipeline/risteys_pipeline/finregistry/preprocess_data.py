"""Functions for preprocessing FinRegistry data"""

import pandas as pd


def preprocess_endpoints_data(df):
    """Applies the following preprocessing steps to endpoints data: 
        - excludes omitted endpoints
        - drops "omit" column
    """
    df = df[df["omit"].isnull()].drop(columns=["omit"])
    return df
