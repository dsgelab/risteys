import re
from datetime import datetime

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


def filter_days(dataf, since_day):
    return dataf.filter(pl.col("DateTime").dt.date() >= since_day)


def assign_bots(dataf):
    return dataf.with_columns(
        pl.when(
            pl.col("Path").str.ends_with(".php")
            | pl.col("UserAgent").str.to_lowercase().str.contains("bot")
        ).then(pl.lit("Bot"))
        .otherwise(pl.lit("User"))
        .alias("Requester")
    )
