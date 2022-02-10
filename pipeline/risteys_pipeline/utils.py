"""Utils functions"""

DAYS_IN_YEAR = 365.25


def to_decimal_year(date_col):
    """Format date to a decimal year"""
    decimal_year = date_col.dt.year + (date_col.dt.dayofyear - 1) / DAYS_IN_YEAR
    return decimal_year
