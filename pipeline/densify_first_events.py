"""
Transform the wide-format first-event file into a long-format / "dense".

The orignal wide-format first-event file has a huge amount of
columns. Some tools like Pandas or SQLite don't deal really well with
that, so we transform the data to make this easier.
We keep only the data if an individual has an endpoint.

Note that this script doesn't do any input validation. It's also why it's quite fast.


Usage
-----
  python densify_first_events.py <path-first-events> > <output-path>

Note the stdout redirection with '>'.


Input file
----------
- First events
  First-event file with a matrix-like structure:
  . columns: endpoints with additional columns for age, year, number of events
  . rows: one individual per row
  Source: FinnGen data


Output
------
Ouputs to stdout by default, use redirection to put the result in a file.
- Dense first events
  CSV format
  . columns: individual FinnGen ID, endpoint, age, year, number of events
  . rows: one row per event, so an individual's events span multiple rows

"""

from pathlib import Path
from sys import argv


OUT_HEADER = "FINNGENID,ENDPOINT,AGE,YEAR,NEVT"


def main():
    print(OUT_HEADER)

    # Input file
    fp = Path(argv[1])
    f = open(fp)

    # Read the header to build a lookup table for column -> column index
    in_header = {}
    for idx, col in enumerate(
            f.readline()
            .rstrip("\n")
            .split(",")):
        in_header[col] = idx

    # Find endpoint columns
    endpoints = list(filter(
        lambda c: c + "_AGE" in in_header and c + "_YEAR" in in_header and c + "_NEVT" in in_header,
        in_header))

    # For each individual, check which endpoints they have, format it and output it
    for row in f:
        records = row.rstrip("\n").split(",")

        for endp in endpoints:
            col = in_header[endp]
            if records[col] == "1":
                # Get the event info
                col_age = in_header[endp + "_AGE"]
                col_year = in_header[endp + "_YEAR"]
                col_nevt = in_header[endp + "_NEVT"]
                val_fgid = records[0]
                val_age = records[col_age]
                val_year = records[col_year]
                val_nevt = records[col_nevt]

                print(f"{val_fgid},{endp},{val_age},{val_year},{val_nevt}")

    f.close()


if __name__ == "__main__":
    main()
