"""Utils functions"""
from contextlib import contextmanager

import pandas as pd

from risteys_pipeline.log import logger


DAYS_IN_YEAR = 365.25


def to_decimal_year(date_col):
    """Format date to a decimal year"""
    date_col = pd.to_datetime(date_col, infer_datetime_format=True)
    decimal_year = date_col.dt.year + (date_col.dt.dayofyear - 1) / DAYS_IN_YEAR
    return decimal_year


@contextmanager
def log_if_diff(name, count_func):
    """Warn if the context body changes the result of `count_func`"""
    count_pre = count_func()
    yield
    count_post = count_func()

    diff = count_post - count_pre
    if diff != 0:
        logger.warning(f"{name} Δ = {diff} ({100 * (count_post - count_pre) / count_pre:.2f}%)")
