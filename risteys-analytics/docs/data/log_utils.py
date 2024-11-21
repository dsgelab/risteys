import re
from datetime import datetime

import polars as pl


def parse_log_file(filepath):
    parsed_lines = []
    with open(filepath, errors="replace") as fd:
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


def filter_days(dataf, since_day):
    return dataf.filter(pl.col("DateTime").dt.date() >= since_day)


def assign_bots(dataf):
    return dataf.with_columns(
        pl.when(
            # Generic bot identification
            pl.col("Path").str.ends_with(".php")
            | pl.col("UserAgent").str.to_lowercase().str.contains("bot")
            | pl.col("UserAgent").str.to_lowercase().str.contains("crawler")
            | pl.col("UserAgent").str.to_lowercase().str.contains("spider")

            # "-" is used in the logs when the user agent is not defined, this
            # was identified as bot behaviour on 2024-04-15.
            | (pl.col("UserAgent") == "-")

            # Identified bot behaviour on 2024-04-28, bot looking for security
            # holes in non-existing pages.
            # Bot is using user agent "VivoBrowser/8.9.0.0 uni-app Html5Plus/1.0"
            | (
                pl.col("UserAgent").str.contains("VivoBrowser")
                & pl.col("UserAgent").str.contains("uni-app")
            )
        ).then(pl.lit("Bot"))
        .otherwise(pl.lit("User"))
        .alias("Requester")
    )
