# TODO(Vincent 2024-04-25)
# Add Finland timezone to date / datetime.
import argparse
from pathlib import Path

import polars as pl


def main():
    args = init_cli()

    to_parquet(
        args.processed_kanta_data_file,
        args.output,
        args.zstd_compression_level
    )


def init_cli():
    description = (
        "Convert the Kanta lab values phase2 pre-processed data "
        "from TSV to Parquet."
    )
    parser = argparse.ArgumentParser(description=description)

    parser.add_argument(
        "--processed-kanta-data-file",
        help="path to Kanta lab value v2 processed data (TSV)",
        required=True,
        type=Path
    )

    parser.add_argument(
        "--output",
        help="path to output file (Parquet)",
        required=True,
        type=Path
    )

    # Use Zstd as inner compression within the Parquet file. The idea is lower
    # the file size without too much compute time overhead.
    #
    # Some benchmarks made around 2024-04-10 on FinRegistry data (was using
    # "NA" as null):
    # - level=3  --> 466.k rows/s, 23.3% size of original uncompressed file
    # - level=12 --> 97.9k rows/s, 19.8% size of original uncompressed file
    # - level=16 --> 27.5k rows/s, 18.0% size of original uncompressed file
    zstd_default_comp_level = 3
    zstd_comp_levels = list(range(1, 23))
    parser.add_argument(
        "--zstd-compression-level",
        help=f"Zstandard compression level (1‒22) for output file (default: {zstd_default_comp_level})",
        required=False,
        action='store',
        type=int,
        default=zstd_default_comp_level,
        choices=zstd_comp_levels
    )

    args = parser.parse_args()

    return args


def to_parquet(input_path, output_path, zstd_compression_level):
    (
        pl.scan_csv(
            input_path,
            separator="\t",
            schema={
                "FINREGISTRYID": pl.String,
                "LAB_DATE_TIME": pl.Datetime(time_unit="ms"),  # We have second precision in the data, but "ms" is the closest provided by the API.
                "LAB_SERVICE_PROVIDER": pl.String,  # Has some "NA" values
                "LAB_ID": pl.String,
                "LAB_ID_SOURCE": pl.UInt8,
                "LAB_ABBREVIATION": pl.String,  # Has some "NA" values
                "LAB_VALUE": pl.Float64,  # ! NO "NA" values
                "LAB_UNIT": pl.String,  # Has some "NA" values
                "OMOP_ID": pl.String,  # Has some "NA" values
                "OMOP_NAME": pl.String,  # Has some "NA" values
                "LAB_ABNORMALITY": pl.String,  # Has some "NA" values
                "MEASUREMENT_STATUS": pl.String,  # Has some "NA" values
                "REFERENCE_VALUE_TEXT": pl.String  # Has some "NA" values
            },
            # NOTE(Vincent 2024-04-11)
            # As far as I understand, polars will skip `null` values on
            # computation, however for our case we want to keep them for
            # non-numerical columns. For example, we want to be able to
            # aggregate data on OMOP_ID even when that is null.
            # So for now I set it so to don't interpret any "NA" as `null` since
            # we only have "NA" on text column. If there is a need for having
            # `null` values, then specify it by column.
            #
            # Some examples of null value handling by polars:
            # 1. Doing a `.group_by().agg( .count())` will not count the null
            #    values.
            # 2. Doing a `.filter( .is_in([...]))` will not include null values
            #    even if null is specified by `is_in()`.
            null_values={},
        )
        .sink_parquet(
            output_path,
            compression="zstd",
            compression_level=zstd_compression_level
        )
    )


if __name__ == '__main__':
    main()
