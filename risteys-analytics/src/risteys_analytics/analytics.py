import re
from datetime import date
from datetime import datetime
from datetime import timedelta

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
    pre_processed = (
        dataf.pipe(filter_out_bots)
        .pipe(filter_in_known_routes)
        .pipe(filter_days, last_n_days=last_n_days)
    )

    stats_top_hits = top_hits(pre_processed, limit=20)
    stats_hits_per_day = hits_per_day(pre_processed)
    stats_top_errors = top_errors(pre_processed, limit=20)

    return (stats_top_hits, stats_hits_per_day, stats_top_errors)


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


def filter_days(dataf, last_n_days):
    today = date.today()
    date_threshold = today - timedelta(days=last_n_days)
    return dataf.filter(pl.col("DateTime").dt.date() > date_threshold)


def top_hits(dataf, limit):
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
