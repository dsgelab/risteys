"""
Transform the wide-format first-event file into a long-format.

The orignal wide-format first-event file has a huge amount of
columns. Some tools like Pandas or SQLite don't deal really well with
that, so we transform the data to make this easier.
We keep only the data if an individual has an endpoint.

Note that this script doesn't do any input validation. It's also why it's quite fast.


Usage
-----
  python wide_to_long_endpoint_first_events.py --help


Input file
----------
- First events
  First-event file with a matrix-like structure:
  . columns: endpoints with additional columns for age, day, number of events
  . rows: one individual per row
  Source: FinnGen data


Output
------
Outputs a Parquet file in long format with all control information discarded.
- Long format first events
  Parquet format
  . columns: individual FinnGen ID, endpoint, age, day, number of events
  . rows: one row per event, so all the events from the same individual span multiple rows
"""

import argparse
from pathlib import Path

import pyarrow
import pyarrow.parquet as parquet


# How the controls, cases, and excluded controls are coded in the input file
CONTROL      = "0"
CASE         = "1"
EXCL_CONTROL = "NA"

# Headers of the output file
OUT_HEADER = [
    "FINNGENID",
    "ENDPOINT",
    # Input notation:  control=0, case=1, excluded control=NA
    # Output notation: control=1, case=1, excluded control=2
    "CONTROL_CASE_EXCL",
    "AGE",
    "APPROX_EVENT_DAY",
    "NEVT"
]


def cli_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-i", "--input-first-events",
        help="path to the FinnGen first-event phenotype file (CSV)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-o", "--output",
        help="path to output long-format file (Parquet)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-k", "--keep-all",
        help="keep all of controls, excluded controls, and cases, instead of keeping only the cases",
        required=False,
        action="store_true"
    )
    args = parser.parse_args()
    return args


def main():
    args = cli_parser()

    in_file = open(args.input_first_events)

    # Read the header to build a lookup table for column -> column index
    in_header = {}
    for idx, col in enumerate(
            in_file.readline()
            .rstrip("\n")
            .split(",")):
        in_header[col] = idx

    # Find endpoint columns
    endpoints = list(filter(
        lambda c: c + "_FU_AGE" in in_header and c + "_APPROX_EVENT_DAY" in in_header and c + "_NEVT" in in_header,
        in_header))

    # Initialize arrays that will be used to make the Parquet output file
    fgid_values = []
    endpoint_values = []
    kind_values = []
    age_values = []
    day_values = []
    nevt_values = []

    # Get the endpoint data for each individual
    for row in in_file:
        records = row.rstrip("\n").split(",")

        for endp in endpoints:
            col = in_header[endp]
            val_endp = records[col]
            val_fgid = records[0]

            # Check if case, control or excluded control
            if val_endp not in (CONTROL, CASE, EXCL_CONTROL):
                raise ValueError(f"Unexpected value `{val_endp}` for `{val_fgid}` with endpoint `{endp}` .")
            elif val_endp == EXCL_CONTROL:
                kind = "2"
            else:
                kind = val_endp

            # Get the event info
            if args.keep_all or kind == CASE:
                col_age = in_header[endp + "_FU_AGE"]
                col_day = in_header[endp + "_APPROX_EVENT_DAY"]
                col_nevt = in_header[endp + "_NEVT"]
                val_age = records[col_age]
                val_day = records[col_day]
                val_nevt = records[col_nevt]

                fgid_values.append(val_fgid)
                endpoint_values.append(endp)
                kind_values.append(int(kind))
                age_values.append(float(val_age))
                day_values.append(val_day)
                nevt_values.append(int(val_nevt))

    in_file.close()

    out_table = pyarrow.table(
        [
            fgid_values,
            endpoint_values,
            kind_values,
            age_values,
            day_values,
            nevt_values,
        ],
        names=OUT_HEADER
    )
    parquet.write_table(out_table, args.output)


if __name__ == "__main__":
    main()
