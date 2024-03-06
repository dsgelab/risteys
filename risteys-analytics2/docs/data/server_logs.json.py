import json
import re
import sys
from datetime import date
from datetime import datetime
from datetime import timedelta
from pathlib import Path

import polars as pl


def parse_log_file(filepath):
    parsed_lines = []
    with open(filepath) as fd:
        for line in fd:
            parsed = parse_log_line(line)

            if parsed is not None:
                parsed_lines.append(parsed)

    return pl.DataFrame(
        parsed_lines, schema=["DateTime", "Path", "StatusCode", "UserAgent"]
    )


def parse_log_line(line):
    line = line.strip()

    pattern = r'REDACTED - - \[(.{26})\] "\w+ (.*) HTTP/.*" (.*) \d+ ".*" "(.*)"'
    res = re.match(pattern, line)

    if res is None:
        return None

    else:
        date_time, request_path, status_code, user_agent = res.groups()
        date_time_parsed = datetime.strptime(date_time, "%d/%b/%Y:%H:%M:%S %z")
        return date_time_parsed, request_path, int(status_code), user_agent


def analyse(dataf, last_n_days):
    today = date.today()
    since_day = today - timedelta(days=last_n_days)
    dataf_recent = filter_days(dataf, since_day)

    total_hits = dataf_recent.shape[0]
    user_hits = (
        dataf_recent
        .pipe(filter_out_bots)
        .shape[0]
    )
    bot_hits = total_hits - user_hits

    relative_user_hits = user_hits / total_hits
    relative_bot_hits = bot_hits / total_hits

    min_date = since_day.isoformat()
    max_date = today.isoformat()

    dataf_user_hits = (
        dataf_recent
        .pipe(filter_out_bots)
        .pipe(filter_in_known_routes)
    )

    stats_hits_per_day = (
        dataf_user_hits
        .pipe(hits_per_day)
        .cast({"Day": pl.String})
        .to_dicts()
    )

    top_page_hits = (
        dataf_user_hits
        .pipe(top_hits, limit=20)
        .to_dicts()
    )

    return {
        "traffic": [
            {"source": "Bots", "relative_hits": relative_bot_hits},
            {"source": "Users", "relative_hits": relative_user_hits}
        ],
        "time_span": {
            "min_date": min_date,
            "max_date": max_date
        },
        "stats_hits_per_day": stats_hits_per_day,
        "top_page_hits": top_page_hits
    }


def filter_out_bots(dataf):
    return dataf.filter(
        (~pl.col("Path").str.ends_with(".php"))
        & (~pl.col("UserAgent").str.to_lowercase().str.contains("bot"))
    )


def filter_in_known_routes(dataf):
    return dataf.filter(
        (pl.col("Path") == "/")
        | pl.col("Path").str.starts_with("/changelog")
        | pl.col("Path").str.starts_with("/documentation")
        | pl.col("Path").str.starts_with("/endpoint/")
        | pl.col("Path").str.starts_with("/endpoints/")
        | pl.col("Path").str.starts_with("/phenocode/")
        | pl.col("Path").str.starts_with("/random_endpoint")
    )


def filter_days(dataf, since_day):
    return dataf.filter(pl.col("DateTime").dt.date() >= since_day)


def top_hits(dataf, limit):
    return (
        dataf
        .with_columns(
            pl.when(
                (pl.col("StatusCode") >= 400) & (pl.col("StatusCode") <= 599)
            )
            .then(pl.lit("Error"))
            .otherwise(pl.lit("OK"))
            .alias("RequestResult")
        )
        .group_by("Path", "RequestResult")
        .agg(pl.len().alias("NHits"))
        .with_columns(
            pl.col("NHits").sum().over("Path").alias("NHitsTotal")
        )
        .sort("NHitsTotal", descending=True)
        .head(limit)
    )


def top_hits_old(dataf, limit):
    return (
        dataf.group_by("Path")
        .agg(pl.len().alias("NHits"))
        .sort("NHits", descending=True)
        .head(limit)
    )


def hits_per_day(dataf):
    return (
        dataf.with_columns(pl.col("DateTime").dt.date().alias("Day"))
        .group_by("Day")
        .agg(pl.len().alias("HitsPerDay"))
        .sort("Day")
    )


def top_errors(dataf, limit):
    return (
        dataf.filter((pl.col("StatusCode") >= 400) & (pl.col("StatusCode") <= 599))
        .group_by("Path")
        .agg(pl.len().alias("NHits"))
        .sort("NHits", descending=True)
        .head(limit)
    )


if __name__ == '__main__':
    log_file = Path(__file__).with_name("access.log")

    df = parse_log_file(log_file)
    stats = analyse(df, last_n_days=30)

    json.dump(stats, sys.stdout)
