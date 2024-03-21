import json
import sys
from datetime import date
from datetime import timedelta
from pathlib import Path

import polars as pl

from log_utils import assign_bots
from log_utils import filter_days
from log_utils import parse_log_file


def make_timeline(dataf):
    today = date.today()
    since_day = today - timedelta(days=30)

    timeline = (
        dataf
        .pipe(filter_days, since_day)
        .pipe(assign_bots)
        .with_columns(
            pl.col("DateTime").dt.truncate("1h").cast(pl.String).alias("HourTruncated"),
            (
                pl.col("DateTime").dt.minute().cast(pl.UInt32)
                + ((pl.col("DateTime").dt.second()).cast(pl.UInt32) / 60)
            ).alias("AtMinute"),
            pl.col("DateTime").cast(pl.String),
        )
        .to_dicts()
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

