import argparse
from pathlib import Path

import pandas as pd


def main(dense_fevents, fg_minimum, keep_red_data, output_dir):
    df = load_data(dense_fevents, fg_minimum)

    # Counts by Endpoint, Sex, Age
    counts_endp_sex_age = df.groupby(["ENDPOINT", "SEX", "AGE"]).count().reset_index()

    # Counts by Endpoint, Sex, Year
    counts_endp_sex_year = df.groupby(["ENDPOINT", "SEX", "YEAR"]).count().reset_index()

    # Remove individual-level data
    if not keep_red_data:
        counts_endp_sex_age = counts_endp_sex_age.loc[counts_endp_sex_age.FINNGENID > 5, :]
        counts_endp_sex_year = counts_endp_sex_year.loc[counts_endp_sex_year.FINNGENID > 5, :]

    # Output data-frames
    counts_endp_sex_age.rename(
        columns={"FINNGENID": "count"}
    ).loc[
        :,
        ["ENDPOINT", "SEX", "AGE", "count"]
    ].to_csv(output_dir / "counts_endp_sex_age.csv", index=False)

    counts_endp_sex_year.rename(
        columns={"FINNGENID": "count"}
    ).loc[
        :,
        ["ENDPOINT", "SEX", "YEAR", "count"]
    ].to_csv(output_dir / "counts_endp_sex_year.csv", index=False)


def parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "-d", "--dense-first-events",
        help="path to first event file in dense format (CSV)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-m", "--fg-minimum",
        help="path to the FinnGen minimum file (CSV)",
        required=True,
        type=Path
    )
    parser.add_argument(
        "-k", "--keep-red-data",
        help="if set will put all data, including individual-level data (red), in output",
        action="store_true"
    )
    parser.add_argument(
        "-o", "--output-dir",
        help="path to the output directory",
        required=True,
        type=Path
    )

    args = parser.parse_args()
    return args


def load_data(path_fevents, path_minimum):
    df_fevents = pd.read_csv(path_fevents, usecols=["FINNGENID", "ENDPOINT", "AGE", "YEAR"])
    df_fevents["AGE"] = df_fevents.AGE.astype({"AGE": "int32"})
    df_minimum = pd.read_csv(path_minimum, usecols=["FINNGENID", "SEX"])

    df = df_fevents.merge(df_minimum, on="FINNGENID", how="left")
    return df


if __name__ == '__main__':
    args = parse_args()
    main(args.dense_first_events, args.fg_minimum, args.keep_red_data, args.output_dir)
