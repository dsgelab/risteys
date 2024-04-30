# TODO(Vincent 2024-04-09)
# New configuration to accomodate for FinnGen and FinRegistry:
# [paths.input]
# minim...
# preproc...

# [paths.output]
# base_run_dir...

# [pipeline]
# partition_by_omopid = true | false
# use_previous_partitioned_data_if_any = true | false
#
# With layout:
# . base_run_dir/
# \_.  run_TIMESTAMP/
#    \_. partition_by_omopid/
#    \_. stats/
#    \_. log.txt
#    \_. conf.toml

# TODO(Vincent 2024-04-29)
# Save log as text in run dir.

# TODO(Vincent 2024-04-29)
# Add memory and CPU history usage in output.
# Maybe there is a common format for this? Maybe Perfetto.
# Would be nice to have some trace associated with it, to understand which tasks
# are long or memory heavy.

# TODO(Vincent 2024-04-29)
# Maybe use JSON for stats output?
# Because the schema can be inferred correctly, instead of CSV being all strings.


import argparse
import datetime
import pprint
import sys
import tomllib
from pathlib import Path

import polars as pl

import split_by_omopid
import stats
from log import logger


# Runtime constants
ERROR_CODE_PREFLIGHT = 1


def main():
    logger.info("Hello! Let's compute. =)")

    # Parse CLI arguments
    args = init_cli()

    # Loading configuration from file
    config = parse_config(args.config)

    # Performing preflight checks
    preflight_checks(config)

    # Running and finding files split by OMOP_ID
    if config["pipeline_steps"]["split_by_omopid"]["run"]:
        split_by_omopid.do_split(
            kanta_preprocessed_file=config["paths"]["kanta_preprocessed_file"],
            output_directory=config["pipeline_steps"]["split_by_omopid"]["output_directory"]
        )

    all_omop_split_files = find_omop_ids_from_directory(config["pipeline_steps"]["split_by_omopid"]["output_directory"])

    # Running stats pipeline
    if config["pipeline_steps"]["compute_stats"]["run"]:
        logger.info(f"Computing stats for {len(all_omop_split_files)} OMOP Concept IDs")

        stats_run_directory = make_stats_run_directory(config["pipeline_steps"]["compute_stats"]["output_directory"])
        logger.info(f"Outputting stats files in {stats_run_directory}")

        for ii, omop_id_split_file in enumerate(all_omop_split_files, start=1):
            omop_id = get_omop_id_from_path(omop_id_split_file)

            logger.debug(f"Computing stats for {omop_id=} ({ii}/{len(all_omop_split_files)} {100 * ii / len(all_omop_split_files):.2f})%")

            stats.pipeline(
                omop_id=omop_id,
                kanta_preprocessed_file=omop_id_split_file,
                minimum_phenotype_file=config["pipeline_steps"]["compute_stats"]["minimum_phenotype_file"],
                output_directory=stats_run_directory,
            )

        logger.info(f"Computing stats for {len(all_omop_split_files)} OMOP Concept IDs: Done")

    # TODO(Vincent 2024-04-24)
    # Add a gather step to concatenate stats files for the different OMOP_ID into 1 file

    logger.info("Compute done.")


def init_cli():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--config",
        help="path to configuration file (TOML)",
        required=True,
        type=Path
    )

    args = parser.parse_args()

    return args


def parse_config(config_file):
    with open(config_file, "rb") as ff:
        config = tomllib.load(ff)

    logger.info("Configuration used for this run:")
    pprint.pp(config, stream=sys.stderr)

    # Cast paths from str to Path
    config["paths"]["kanta_preprocessed_file"] = Path(config["paths"]["kanta_preprocessed_file"])
    config["pipeline_steps"]["split_by_omopid"]["output_directory"] = Path(config["pipeline_steps"]["split_by_omopid"]["output_directory"])
    config["pipeline_steps"]["compute_stats"]["minimum_phenotype_file"] = Path(config["pipeline_steps"]["compute_stats"]["minimum_phenotype_file"])
    config["pipeline_steps"]["compute_stats"]["output_directory"] = Path(config["pipeline_steps"]["compute_stats"]["output_directory"])

    return config


def preflight_checks(config):
    logger.info("Performing preflight checks")

    kanta_preprocessed_file = config["paths"]["kanta_preprocessed_file"]
    minimum_phenotype_file = config["pipeline_steps"]["compute_stats"]["minimum_phenotype_file"]
    stats_directory = config["pipeline_steps"]["compute_stats"]["output_directory"]
    split_directory = config["pipeline_steps"]["split_by_omopid"]["output_directory"]

    # IO checks
    def does_file_exist(path):
        try:
            path.open()
        except OSError as ee:
            logger.error(ee)
            return False
        else:
            return True

    def is_directory_writable(directory):
        touch_file = directory / ".CAN_WRITE"
        try:
            touch_file.touch()
        except OSError as ee:
            logger.error(ee)
            return False
        else:
            return True

    ok_kanta = does_file_exist(kanta_preprocessed_file)
    ok_phenotype = does_file_exist(minimum_phenotype_file)
    ok_stats_directory = is_directory_writable(stats_directory)
    ok_split_directory = is_directory_writable(split_directory)

    split_directory_n_files = len(list(split_directory.glob("*.parquet")))

    if config["pipeline_steps"]["split_by_omopid"]["run"] and split_directory_n_files > 0:
        logger.error(f"Run configured with 'split_by_omopid' but {split_directory_n_files} split files already exist.")
        ok_split_directory_files = False

    elif not config["pipeline_steps"]["split_by_omopid"]["run"] and split_directory_n_files == 0:
        logger.error("Run configured to skip 'split_by_omopid' but no split files found.")
        ok_split_directory_files = False

    else:
        ok_split_directory_files = True

    # Data checks
    kanta_expected_schema = {
        'FINREGISTRYID': pl.String,
        'LAB_DATE_TIME': pl.Datetime(time_unit='ms', time_zone=None),  # TODO(Vincent 2024-04-25) switch to Helinski timezone
        'LAB_SERVICE_PROVIDER': pl.String,
        'LAB_ID': pl.String,
        'LAB_ID_SOURCE': pl.UInt8,
        'LAB_ABBREVIATION': pl.String,
        'LAB_VALUE': pl.Float64,
        'LAB_UNIT': pl.String,
        'OMOP_ID': pl.String,
        'OMOP_NAME': pl.String,
        'LAB_ABNORMALITY': pl.String,
        'MEASUREMENT_STATUS': pl.String,
        'REFERENCE_VALUE_TEXT': pl.String
    }

    kanta_schema = pl.scan_parquet(kanta_preprocessed_file).schema
    ok_kanta_schema = kanta_schema == kanta_expected_schema

    if not ok_kanta_schema:
        message = (
            f"Wrong dataframe schema for {kanta_preprocessed_file=}.\n"
            f"Got: {kanta_schema}.\n"
            f"Expected: {kanta_expected_schema}."
        )
        logger.error(message)

    if (
        not ok_kanta or
        not ok_phenotype or
        not ok_stats_directory or
        not ok_split_directory or
        not ok_split_directory_files or
        not ok_kanta_schema
    ):
        exit(ERROR_CODE_PREFLIGHT)

    logger.info("Performing preflight checks: Done")


def find_omop_ids_from_directory(path_directory):
    omop_id_split_paths = path_directory.glob("*.parquet")
    omop_id_split_paths = list(omop_id_split_paths)

    logger.info(f"Found {len(omop_id_split_paths)} split files in {path_directory}")

    return omop_id_split_paths


def get_omop_id_from_path(omop_id_split_file):
    return omop_id_split_file.stem


def make_stats_run_directory(base_directory):
    datetime_now = (
        datetime.datetime.now()
        .isoformat()
    )

    name = f"run_{datetime_now}"
    stats_run_directory = base_directory / name

    stats_run_directory.mkdir()

    return stats_run_directory


if __name__ == "__main__":
    main()
