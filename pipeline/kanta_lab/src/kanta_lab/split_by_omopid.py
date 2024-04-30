"""
Split the Kanta pre-processed data file into multiple Parquet files based on
the OMOP_ID.

This operation is very time consuming (~ 24 hours for 1.2G records with ~1k
OMOP_ID) but allows subsequently computing stats per OMOP_ID without using much
RAM.
"""

import polars as pl

from log import logger


def do_split(*, kanta_preprocessed_file, output_directory):
    logger.info("Splitting data by OMOP_ID (can take ~24h for 1.2G records with 1.2k OMOP_ID)")

    all_omop_ids = gather_all_omop_ids(kanta_preprocessed_file)
    total = all_omop_ids.shape[0]

    for ii, omop_id in enumerate(all_omop_ids, start=1):
        logger.debug(f"Splitting on {omop_id=:10} ({ii}/{total} {100 * ii / total:.2f}%)")

        write_split_file(
            kanta_preprocessed_file,
            omop_id,
            output_directory
        )

    logger.info("Splitting data by OMOP_ID: Done")


def gather_all_omop_ids(kanta_preprocessed_file):
    return (
        pl.scan_parquet(kanta_preprocessed_file)
        .select(
            pl.col("OMOP_ID").unique()
        )
        .collect()
        .get_column("OMOP_ID")
    )


def write_split_file(kanta_preprocessed_file, omop_id, output_directory):
    output_file = output_directory / f"{omop_id}.parquet"

    (
        pl.scan_parquet(kanta_preprocessed_file)
        .filter(
            pl.col("OMOP_ID") == omop_id
        )
        .sink_parquet(output_file)
    )
