import json

import numpy as np
import polars as pl

from log import logger


# TODO(Vincent 2024-04-25)
# Should these be put in the configuration file?
# That would help in understanding how the data was produced.
# Data related constants
OUTPUT_NULL_VALUE = "NA"

AGE_BIN_BREAKS = list(range(0, 101))
DIST_N_BREAKS = 100
QUANTILE_BREAK_MAX = 0.99

DATE_STUDY_START = pl.date(2014, 1, 1)


def pipeline(*, omop_id, kanta_preprocessed_file, minimum_phenotype_file, output_directory):
    logger.debug(f"Running stats pipeline for {omop_id=}")
    compute_n_people_median_n_measurements(
        omop_id=omop_id,
        data_path=kanta_preprocessed_file,
        output_dir=output_directory
    )

    compute_median_duration_first_to_last(
        omop_id=omop_id,
        data_path=kanta_preprocessed_file,
        output_dir=output_directory
    )

    compute_count_by_sex(
        omop_id=omop_id,
        data_path=kanta_preprocessed_file,
        pheno_path=minimum_phenotype_file,
        output_dir=output_directory,
    )

    compute_dist_variability(
        omop_id=omop_id,
        data_path=kanta_preprocessed_file,
        output_dir=output_directory
    )

    compute_dist_year_birth(
        omop_id=omop_id,
        data_path=kanta_preprocessed_file,
        pheno_path=minimum_phenotype_file,
        output_dir=output_directory
    )

    compute_dist_duration_first_to_last(
        omop_id=omop_id,
        data_path=kanta_preprocessed_file,
        output_dir=output_directory
    )

    compute_dists_age(
        omop_id=omop_id,
        data_path=kanta_preprocessed_file,
        pheno_path=minimum_phenotype_file,
        output_dir=output_directory
    )

    compute_dist_lab_values(
        omop_id=omop_id,
        data_path=kanta_preprocessed_file,
        output_dir=output_directory
    )

    compute_dist_n_measurements_over_years(
        omop_id=omop_id,
        data_path=kanta_preprocessed_file,
        output_dir=output_directory
    )

    compute_dist_n_measurements_person(
        omop_id=omop_id,
        data_path=kanta_preprocessed_file,
        output_dir=output_directory
    )

    compute_qc_tables(
        omop_id=omop_id,
        data_path=kanta_preprocessed_file,
        output_dir=output_directory
    )

    logger.debug(f"Running stats pipeline for {omop_id=}: Done")


def compute_n_people_median_n_measurements(*, omop_id, data_path, output_dir):
    logger.debug("Computing N people, and Median(N measurements / person)")

    output_path = output_dir / f"median_n_measurements__{omop_id}.csv"

    (
        pl.scan_parquet(data_path)
        .filter(pl.col("OMOP_ID") == omop_id)
        .group_by(["OMOP_ID", "FINREGISTRYID"])
        .agg(
             pl.col("FINREGISTRYID").count().alias("CountPerPerson")
         )
        .group_by("OMOP_ID")
        .agg(
            pl.col("CountPerPerson").median().alias("MedianNMeasurementsPerPerson"),
            pl.col("FINREGISTRYID").n_unique().alias("NPeople"),
        )
        .pipe(keep_green, column_n_people="NPeople")
        .collect()
    ).write_csv(output_path, null_value=OUTPUT_NULL_VALUE)

    logger.debug("Computing N people, and Median(N measurements / person): Done")


def compute_median_duration_first_to_last(*, omop_id, data_path, output_dir):
    logger.debug("Computing Median(duration from first to last measurement / person)")

    output_path = output_dir / f"median_duration_first_to_last_measurement__{omop_id}.csv"

    # Minimum number of measurements per person, to filter people with only 1 measurements.
    min_count_per_person = 2

    (
        pl.scan_parquet(data_path)
        .filter(pl.col("OMOP_ID") == omop_id)
        .group_by(["OMOP_ID", "FINREGISTRYID"])
        .agg(
            pl.col("FINREGISTRYID").count().alias("CountPerPerson"),
            (pl.col("LAB_DATE_TIME").max() - pl.col("LAB_DATE_TIME").min())
            .dt.total_days()
            .alias("DurationDaysFirstToLast"),
        )
        .filter(pl.col("CountPerPerson") >= min_count_per_person)
        .group_by("OMOP_ID")
        .agg(
            pl.col("DurationDaysFirstToLast")
            .median()
            .alias("MedianDurationDaysFirstToLast"),
            pl.col("FINREGISTRYID").n_unique().alias("NPeopleAfterFilterOut"),
        )
        .pipe(keep_green, column_n_people="NPeopleAfterFilterOut")
        .collect()
    ).write_csv(output_path, null_value=OUTPUT_NULL_VALUE)

    logger.debug("Computing Median(duration from first to last measurement / person): Done")


def compute_count_by_sex(*, omop_id, data_path, pheno_path, output_dir):
    logger.debug("Computing count by sex")

    output_path = output_dir / f"count_by_sex__{omop_id}.csv"

    # Sex encoding according to FINREGISTRY data dictionnary
    # for the minumum phenotype file.
    sex_code_male = "0"
    sex_code_female = "1"

    df_sex = pl.scan_csv(pheno_path).cast(
        {"FINREGISTRYID": pl.String, "SEX": pl.String}
    )

    (
        pl.scan_parquet(data_path)
        .filter(pl.col("OMOP_ID") == omop_id)
        .join(df_sex, on="FINREGISTRYID", how="left")
        .group_by(["OMOP_ID", "FINREGISTRYID"])
        .agg(pl.col("SEX").first().alias("SexCode"))
        .with_columns(
            pl.when(pl.col("SexCode") == sex_code_male)
            .then(pl.lit("male"))
            .when(pl.col("SexCode") == sex_code_female)
            .then(pl.lit("female"))
            .otherwise(pl.lit("unknown"))
            .alias("Sex")
        )
        .group_by("OMOP_ID", "Sex")
        .agg(pl.col("Sex").count().alias("NPeople"))
        .pipe(keep_green, column_n_people="NPeople")
        .collect()
    ).write_csv(output_path, null_value=OUTPUT_NULL_VALUE)

    logger.debug("Computing count by sex: Done")


def compute_dist_variability(*, omop_id, data_path, output_dir):
    logger.debug("Computing lab value variability distribution")

    output_stats_path = output_dir / f"lab_value_variability_distribution__{omop_id}.csv"
    output_breaks_path = output_dir / f"lab_value_variability_distribution__{omop_id}__breaks.json"

    # Have at least 2 measurements to compute the lab variability, otherwise we just
    # have a giant spicke at 0.
    min_n_measurements = 2

    dataf = (
        pl.scan_parquet(data_path)
        .filter(pl.col("OMOP_ID") == omop_id)
    )

    # NOTE(Vincent 2024-04-26)
    # The distribution doesn't really make sense if it includes all the
    # LAB_UNITs. So I just pick the most comon lab unit and filter on that.
    top_lab_unit = (
        dataf
        .group_by("LAB_UNIT")
        .agg(
            pl.col("LAB_UNIT").count().alias("NRecords"),
            pl.col("FINREGISTRYID").n_unique().alias("NPeople")
        )
        .sort(
            by=["NRecords", "NPeople"],
            descending=True
        )
        .head(1)
        .select(
            pl.col("LAB_UNIT")
        )
        .collect()
        .item()
    )

    dataf = (
        dataf
        .filter(
            pl.col("LAB_UNIT") == top_lab_unit
        )
        .group_by("OMOP_ID", "FINREGISTRYID")
        .agg(
            pl.col("FINREGISTRYID").count().alias("NMeasurements"),
            (pl.col("LAB_VALUE").max() - pl.col("LAB_VALUE").min()).alias("ValueRange")
        )
        .filter(
            (pl.col("NMeasurements") >= min_n_measurements)
        )
    )

    # TODO(Vincent 2024-004-26) ::COLLECT_REUSE
    # I am using a collect() here but then I don't use the materialized
    # dataframe for the stats.
    # Either find a way to not use collect() here, or re-use the materialized
    # dataframe downstream.
    if dataf.collect().is_empty():
        logger.error(
            f"Could not compute lab variability stats for {omop_id=} "
            f"and {top_lab_unit=}: no data after filtering out by N "
            "measurements."
        )
        return

    # Define binning breaks
    break_min = 0  # Smallest (max - min) is 0 for lab value variability
    break_max = (
        dataf
        .select(pl.col("ValueRange").quantile(QUANTILE_BREAK_MAX))
        .collect()
        .item()
    )

    breaks = np.linspace(start=break_min, stop=break_max, num=DIST_N_BREAKS)
    breaks = np.unique(breaks)

    write_breaks(
        omop_id=omop_id,
        breaks=breaks.tolist(),
        left_closed=True,
        output_file=output_breaks_path
    )

    # Binning
    (
        dataf
        .with_columns(
            pl.col("ValueRange").cut(breaks=breaks, left_closed=True).alias("Bin")
        )
        .group_by(["OMOP_ID", "Bin"])
        .agg(
            pl.col("FINREGISTRYID").count().alias("NPeople")
        )
        .pipe(keep_green, column_n_people="NPeople")
        .collect()
        .write_csv(output_stats_path, null_value=OUTPUT_NULL_VALUE)
    )

    logger.debug("Computing lab value variability distribution: Done")


def compute_dist_year_birth(*, omop_id, data_path, pheno_path, output_dir):
    logger.debug("Computing year of birth distribution")

    output_stats_path = output_dir / f"year_of_birth_distribution__{omop_id}.csv"
    output_breaks_path = output_dir / f"year_of_birth_distribution__{omop_id}__breaks.json"

    df_yob = (
        pl.scan_csv(pheno_path).cast({
            "FINREGISTRYID": pl.String,
            "DATE_OF_BIRTH": pl.Date
        })
        .select(
            pl.col("FINREGISTRYID"),
            pl.col("DATE_OF_BIRTH").dt.year().alias("YearOfBirth")
        )
    )

    df = (
        pl.scan_parquet(data_path)
        .select(
            pl.col("OMOP_ID"),
            pl.col("FINREGISTRYID"),
        )
        .filter(pl.col("OMOP_ID") == omop_id)
        .unique(["OMOP_ID", "FINREGISTRYID"])
        .join(df_yob, on="FINREGISTRYID", how="left")
    )

    df_year_range = (
        df
        .select(
            pl.col("YearOfBirth").min().alias("MinYearOfBirth"),
            pl.col("YearOfBirth").max().alias("MaxYearOfBirth")
        )
        .collect()
    )
    min_year = df_year_range.get_column("MinYearOfBirth").item()
    max_year = df_year_range.get_column("MaxYearOfBirth").item()
    bin_width = 1  # in years
    breaks = list(range(min_year, max_year, bin_width))

    write_breaks(
        omop_id=omop_id,
        breaks=breaks,
        left_closed=True,
        output_file=output_breaks_path
    )

    (
        df
        .with_columns(
            pl.col("YearOfBirth").cut(breaks=breaks, left_closed=True).alias("Bin")
        )
        .group_by("OMOP_ID", "Bin")
        .agg(
            pl.col("Bin").count().alias("NPeople")
        )
        .pipe(keep_green, column_n_people="NPeople")
        .collect()
    ).write_csv(
        output_stats_path, null_value=OUTPUT_NULL_VALUE
    )

    logger.debug("Computing year of birth distribution: Done")


def compute_dist_duration_first_to_last(*, omop_id, data_path, output_dir):
    logger.debug("Computing time in cohort distribution")

    output_stats_path = output_dir / f"duration_first_to_last_distribution__{omop_id}.csv"
    output_breaks_path = output_dir / f"duration_first_to_last_distribution__{omop_id}__breaks.json"

    # Only include people with 2 or more measurements
    min_records = 2

    dataf = (
        pl.scan_parquet(data_path)
        .filter(pl.col("OMOP_ID") == omop_id)
        .group_by(["OMOP_ID", "FINREGISTRYID"])
        .agg(
            (
                (pl.col("LAB_DATE_TIME").max() - pl.col("LAB_DATE_TIME").min())
                .dt.total_days()
                .alias("DurationFirstToLast")
            ),
            pl.col("FINREGISTRYID").count().alias("CountRecords")
        )
        .filter(pl.col("CountRecords") >= min_records)
    )

    # TODO(Vincent 2024-004-26) ::COLLECT_REUSE
    if dataf.collect().is_empty():
        logger.error(
            f"Could not compute duration first to last for {omop_id=}:"
            f" no data after filtering out by N records."
        )
        return

    # Define binnin breaks
    break_min = 0
    break_max = (
        dataf
        .select(pl.col("DurationFirstToLast").quantile(QUANTILE_BREAK_MAX))
        .collect()
        .item()
    )
    breaks = np.linspace(start=break_min, stop=break_max, num=DIST_N_BREAKS)
    breaks = np.unique(breaks)

    write_breaks(
        omop_id=omop_id,
        breaks=breaks.tolist(),
        left_closed=True,
        output_file=output_breaks_path
    )

    # Binning
    (
        dataf
        .with_columns(
            pl.col("DurationFirstToLast").cut(breaks=breaks, left_closed=True).alias("Bin")
        )
        .group_by(["OMOP_ID", "Bin"])
        .agg(
            pl.col("FINREGISTRYID").count().alias("NPeople")
        )
        .pipe(keep_green, column_n_people="NPeople")
        .collect()
        .write_csv(output_stats_path, null_value=OUTPUT_NULL_VALUE)
    )

    logger.debug("Computing time in cohort distribution: Done")


def compute_dists_age(*, omop_id, data_path, pheno_path, output_dir):
    logger.debug("Computing age distributions")

    output_age_first_path = output_dir / f"age_first_meas_distribution__{omop_id}.csv"
    output_age_last_path = output_dir / f"age_last_meas_distribution__{omop_id}.csv"
    output_study_start_path = output_dir / f"age_study_start_distribution__{omop_id}.csv"
    output_breaks_path = output_dir / f"age_distribution__{omop_id}__breaks.json"

    # Polars provides a .total_days() but not a .total_years(),
    # so we use this constant to convert X days to Y years.
    days_in_a_year = 365.25

    df_dob = (
        pl.scan_csv(pheno_path).cast({
            "FINREGISTRYID": pl.String,
            "DATE_OF_BIRTH": pl.Date
        })
        .select(
            pl.col("FINREGISTRYID"),
            pl.col("DATE_OF_BIRTH")
        )
    )

    write_breaks(
        omop_id=omop_id,
        breaks=AGE_BIN_BREAKS,
        left_closed=True,
        output_file=output_breaks_path
    )

    df = (
        pl.scan_parquet(data_path)
        .select(
            pl.col("OMOP_ID"),
            pl.col("FINREGISTRYID"),
            pl.col("LAB_DATE_TIME").dt.date().alias("LabDate")
        )
        .filter(pl.col("OMOP_ID") == omop_id)
        .group_by(["OMOP_ID", "FINREGISTRYID"])
        .agg(
            pl.col("LabDate").min().alias("DateFirstMeasurement"),
            pl.col("LabDate").max().alias("DateLastMeasurement")
        )
        .join(df_dob, on="FINREGISTRYID", how="left")
        .with_columns(
            (
                (pl.col("DateFirstMeasurement") - pl.col("DATE_OF_BIRTH")).dt.total_days()
                / days_in_a_year
            ).alias("AgeAtFirstMeasurement_years"),
            (
                (pl.col("DateLastMeasurement") - pl.col("DATE_OF_BIRTH")).dt.total_days()
                / days_in_a_year
            ).alias("AgeAtLastMeasurement_years"),
            (
                (DATE_STUDY_START - pl.col("DATE_OF_BIRTH")).dt.total_days()
                / days_in_a_year
            ).alias("AgeAtStudyStart_years")
        )
        .with_columns(
            pl.col("AgeAtFirstMeasurement_years").cut(breaks=AGE_BIN_BREAKS, left_closed=True)
            .alias("BinAgeAtFirstMeasurement_years"),
            pl.col("AgeAtLastMeasurement_years").cut(breaks=AGE_BIN_BREAKS, left_closed=True)
            .alias("BinAgeAtLastMeasurement_years"),
            pl.col("AgeAtStudyStart_years").cut(breaks=AGE_BIN_BREAKS, left_closed=True)
            .alias("BinAgeAtStudyStart_years")
        )
        # Materialize the LazyFrame query plan into an actual DataFrame at this point
        # because we can take advantage of pre-computing the data now and re-use it
        # a couple of times downstream.
        .collect()
    )

    (
        df
        .group_by("OMOP_ID", "BinAgeAtFirstMeasurement_years")
        .agg(
            pl.col("FINREGISTRYID").count().alias("NPeople")
        )
        .pipe(keep_green, column_n_people="NPeople")
    ).write_csv(
        output_age_first_path,
        null_value=OUTPUT_NULL_VALUE
    )

    (
        df
        .group_by("OMOP_ID", "BinAgeAtLastMeasurement_years")
        .agg(
            pl.col("FINREGISTRYID").count().alias("NPeople")
        )
        .pipe(keep_green, column_n_people="NPeople")
    ).write_csv(
        output_age_last_path,
        null_value=OUTPUT_NULL_VALUE
    )

    (
        df
        .group_by("OMOP_ID", "BinAgeAtStudyStart_years")
        .agg(
            pl.col("FINREGISTRYID").count().alias("NPeople")
        )
        .pipe(keep_green, column_n_people="NPeople")
    ).write_csv(
        output_study_start_path,
        null_value=OUTPUT_NULL_VALUE
    )

    logger.debug("Computing age distributions: Done")


def compute_dist_lab_values(*, omop_id, data_path, output_dir):
    logger.debug("Computing distribution of lab values")

    dataf = (
        pl.scan_parquet(data_path)
        .filter(pl.col("OMOP_ID") == omop_id)
    )

    # Lab values are a bit messy.
    # The LAB_VALUE and LAB_UNIT are sourced from the raw data and were
    # not aligned to the OMOP_ID. So a single OMOP_ID can contain different
    # LAB_UNIT.
    # Additionally, there are different kind of LAB_UNITs:
    # - `binary`: test is positive or negative
    # - `titre`: caterogical values
    # - `NA`: mostly for continuous values?
    # - most other LAB_UNIT look like continuous values

    # I will process the lab values differently wether they are discrete or
    # continuous. If they are discrete, then a bin will be single scalar.
    # Otherwise if they are continuous then a bin willbe  a half-closed range
    # between two values.
    # Since we don't need polars .cut() for discrete values, I compute the
    # bins and counts for them directly.
    discrete_lab_units = ['binary', 'titre']

    output_stats_path = output_dir / f"dist_lab_values__{omop_id}__discrete_lab_units.csv"

    (
        dataf
        .rename({"LAB_VALUE": "Bin"})
        .filter(pl.col("LAB_UNIT").is_in(discrete_lab_units))
        .group_by("OMOP_ID", "LAB_UNIT", "Bin")
        .agg(
            pl.col("Bin").count().alias("NRecords"),
            pl.col("FINREGISTRYID").n_unique().alias("NPeople")
        )
        .pipe(keep_green, column_n_people="NPeople")
        .collect()
        .write_csv(output_stats_path, null_value=OUTPUT_NULL_VALUE)
    )

    dataf_cont = (
        dataf
        .filter(~pl.col("LAB_UNIT").is_in(discrete_lab_units))
    )

    continuous_lab_units = (
        dataf_cont
        .select(pl.col("LAB_UNIT").unique())
        .collect()
        .get_column("LAB_UNIT")
    )

    for lab_unit in continuous_lab_units:
        lab_unit_path_safe = lab_unit.replace("/", ".")
        output_stats_path = output_dir / f"dist_lab_values__{omop_id}__{lab_unit_path_safe}.csv"
        output_breaks_path = output_dir / f"dist_lab_values__{omop_id}__{lab_unit_path_safe}__breaks.json"

        # Define binning breaks, specific for each LAB_UNIT
        break_min = 0
        break_max = (
            dataf_cont
            .select(pl.col("LAB_VALUE").quantile(QUANTILE_BREAK_MAX))
            .collect()
            .item()
        )
        breaks = np.linspace(start=break_min, stop=break_max, num=DIST_N_BREAKS)
        breaks = np.unique(breaks)

        write_breaks(
            omop_id=omop_id,
            breaks=breaks.tolist(),
            left_closed=True,
            output_file=output_breaks_path,
            lab_unit=lab_unit
        )

        # Binning
        (
            dataf_cont
            .filter(pl.col("LAB_UNIT") == lab_unit)
            .with_columns(
                pl.col("LAB_VALUE").cut(breaks=breaks, left_closed=True).alias("Bin")
            )
            .group_by(["OMOP_ID", "LAB_UNIT", "Bin"])
            .agg(
                pl.col("Bin").count().alias("NRecords"),
                pl.col("FINREGISTRYID").n_unique().alias("NPeople")
            )
            .pipe(keep_green, column_n_people="NPeople")
            .collect()
            .write_csv(output_stats_path, null_value=OUTPUT_NULL_VALUE)
        )

    logger.debug("Computing distribution of lab values: Done")


def compute_dist_n_measurements_over_years(*, omop_id, data_path, output_dir):
    logger.debug("Computing N measurements over time distribution")

    output_path = output_dir / f"dist_n_measurements_years__{omop_id}.csv"

    (
        pl.scan_parquet(data_path)
        .filter(pl.col("OMOP_ID") == omop_id)
        .with_columns(
            pl.col("LAB_DATE_TIME").dt.strftime("%Y-%m").alias("YearMonth")
        )
        .group_by("OMOP_ID", "YearMonth")
        .agg(
            pl.col("FINREGISTRYID").n_unique().alias("NPeople"),
            pl.col("YearMonth").count().alias("NRecords")
        )
        .pipe(keep_green, column_n_people="NPeople")
        .collect()
    ).write_csv(
        output_path,
        null_value=OUTPUT_NULL_VALUE
    )

    logger.debug("Computing N measurements over time distribution: Done")


def compute_dist_n_measurements_person(*, omop_id, data_path, output_dir):
    logger.debug("Computing distribution of N measurements per person")

    output_path = output_dir / f"dist_n_measurements_person__{omop_id}.csv"

    (
        pl.scan_parquet(data_path)
        .filter(pl.col("OMOP_ID") == omop_id)
        .group_by("OMOP_ID", "FINREGISTRYID")
        .agg(
            # 'Bin' represents a number of measurements
            pl.col("FINREGISTRYID").count().alias("Bin")
        )
        .group_by("OMOP_ID", "Bin")
        .agg(
            pl.col("Bin").count().alias("NPeople")
        )
        .pipe(keep_green, column_n_people="NPeople")
        .collect()
    ).write_csv(
        output_path,
        null_value=OUTPUT_NULL_VALUE
    )

    logger.debug("Computing distribution of N measurements per person: Done")


def compute_qc_tables(*, omop_id, data_path, output_dir):
    logger.debug("Computing OMOP mapping QC tables")

    output_path = output_dir / f"qc_mapping__{omop_id}.csv"

    (
        pl.scan_parquet(data_path)
        .filter(pl.col("OMOP_ID") == omop_id)
        .group_by("OMOP_ID", "LAB_ID", "LAB_ABBREVIATION", "LAB_UNIT")
        .agg(
            pl.col("OMOP_ID").count().alias("NRecords"),
            pl.col("FINREGISTRYID").n_unique().alias("NPeople"),
            # TODO(Vincent 2024-04-19)
            # Add lab value distributions. Though we want NPeople for each quantile.
        )
        .pipe(keep_green, column_n_people="NPeople")
        .collect()
    ).write_csv(
        output_path,
        null_value=OUTPUT_NULL_VALUE
    )

    logger.debug("Computing OMOP mapping QC tables: Done")


def keep_green(dataframe, *, column_n_people):
    min_n_for_green_data = 5
    logger.debug(
        f"... filtering to keep green data, using column={column_n_people} >= {min_n_for_green_data}"
    )

    return dataframe.filter(pl.col(column_n_people) >= min_n_for_green_data)


def write_breaks(*, omop_id, breaks, left_closed, output_file, **extras_key_val):
    out = {
        "omop_id": omop_id,
        "left_closed": left_closed,
        "breaks": breaks
    }

    for key, val in extras_key_val.items():
        out[key] = val

    with open(output_file, "x") as ff:
        json.dump(out, ff)
