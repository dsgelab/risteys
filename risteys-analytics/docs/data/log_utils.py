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
        parsed_lines,
        schema=["DateTime", "Path", "StatusCode", "UserAgent"],
        orient="row"
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

            # NOTE(Vincent 2024-11-21)
            # Identified bot behaviour happening on 2024-11-10, appending weird query parameters
            # to /endpoints/C3_URINARY_TRACT
            # e.g:
            #   /endpoints/C3_URINARY_TRACT&sa=U&ved=2ahUKEwjZzKaM38qIAxX6SfEDHaNANnsQFnoECAcQAg&usg=3765
            #   /endpoints/C3_URINARY_TRACT&sa=U&ved=2ahUKEwjZzKaM38qIAxX6SfEDHaNANnsQFnoECAcQAg&usg=AOvVaw1jgaK37uq8EyRawip2qxVT%29%2F%2A%2A%2FANd%2F%2A%2A%2F4487%2F%2A%2A%2FBETweEn%2F%2A%2A%2F3334%2F%2A%2A%2FANd%2F%2A%2A%2F3334--%2F%2A%2A%2FDlYr
            # This user agent didn't have any other entries than these weird ones so I flag it as
            # a bot, eventhough it's not obvious from the user agent provided.
            | (pl.col("UserAgent") == "Mozilla/5.0 (X11; U; Linux i686; rv:1.9) Gecko/2008080808 Firefox/3.0")

            # NOTE(Vincent 2024-11-28)
            # Identifed bot behaviour happening on 2024-11-26, full user agent was:
            # "Scrapy/2.11.2 (+https://scrapy.org)"
            | pl.col("UserAgent").str.contains("https://scrapy.org")

            # NOTE(Vincent 2024-11-28)
            # Some low-traffic bots:
            | pl.col("UserAgent").str.starts_with("Go-http-client/")
            | pl.col("UserAgent").str.starts_with("workona-favicon-service/")
            | (pl.col("UserAgent") == "Owler (ows.eu/owler)")
            | pl.col("UserAgent").str.starts_with("facebookexternalhit/")
            | pl.col("UserAgent").str.starts_with("Microsoft Office Excel")
            | pl.col("UserAgent").str.starts_with("Iframely/")
            | pl.col("UserAgent").str.starts_with("python-requests/")
            | pl.col("UserAgent").str.starts_with("GoogleOther/")
        ).then(pl.lit("Bot"))
        .otherwise(pl.lit("User"))
        .alias("Requester")
    )
