import json
import sys
from datetime import date
from datetime import timedelta
from pathlib import Path

import polars as pl

from log_utils import assign_bots
from log_utils import filter_days
from log_utils import parse_log_file


X_RESOLUTION = "1h" # x scale resolution, using polars string language https://docs.pola.rs/py-polars/html/reference/expressions/api/polars.Expr.dt.offset_by.html

SECOND = 1
MINUTE = 60 * SECOND
Y_RESOLUTION = 10 * SECOND   # y scale resolution, in seconds



def make_timeline(dataf):
    today = date.today()
    since_day = today - timedelta(days=30)

    timeline = (
        dataf
        .pipe(filter_days, since_day)
        .pipe(assign_bots)
        .select(
            pl.col("Requester"),
            pl.col("DateTime").dt.truncate(X_RESOLUTION).alias("x1"),
            (
                pl.col("DateTime").dt.minute()
                + (
                    pl.col("DateTime").dt.second()
                    // Y_RESOLUTION * Y_RESOLUTION  # put the second to a 10s wide bin
                    / MINUTE  # plot is using minute as the time scale
                )
            ).alias("y1")
        )
        .with_columns(
            pl.col("x1").dt.to_string("%F %T").alias("x1"),
            pl.col("x1").dt.offset_by(X_RESOLUTION).dt.to_string("%F %T").alias("x2"),
            (pl.col("y1") + Y_RESOLUTION / MINUTE).alias("y2")
        )
        .to_dict(as_series=False)  # To a dict of lists, JSON serializable.
    )

    return {
        "date_range": {
            "from": since_day.isoformat(),
            "to": today.isoformat()
        },
        "timeline": timeline
    }


if __name__ == "__main__":
    log_file = Path(__file__).with_name("access.log")

    dataf = parse_log_file(log_file)
    data_out = make_timeline(dataf)

    json.dump(data_out, sys.stdout)

