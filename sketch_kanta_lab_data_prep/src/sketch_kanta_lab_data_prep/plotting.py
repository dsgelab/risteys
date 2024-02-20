import altair as alt
import polars as pl


ALL_OMOP_IDS = [
    "3020564",
    "3035995",
    "3037522",
]



def plot_age_distrib(file_path, omop_id):
    plot_dataf = (
        load_age_distrib_file(file_path)
        .pipe(prep_age_distrib_dataf, omop_id=omop_id)
    )

    return (
        alt.Chart(plot_dataf).mark_rect().encode(
            alt.X("BinLeft:Q").title("Age (years)"),
            alt.X2("BinRight:Q"),
            alt.Y("NPeople:Q").title("Number of people")
        )
    )


def load_age_distrib_file(file_path):
    return (
        pl.read_csv(
            file_path,
            dtypes={
                "OMOP_ID": pl.String,
                "BinAgeAtFirstMeasurement_years": pl.String,
                "NPeople": pl.UInt64
            }
        )
    )


def prep_age_distrib_dataf(dataf, *, omop_id):
    return (
        dataf
        .pipe(extract_bin_left_right, column_bin="BinAgeAtFirstMeasurement_years")
        .filter(pl.col("OMOP_ID") == omop_id)
        .select(
            pl.col("BinLeft"),
            pl.col("BinRight"),
            pl.col("NPeople")
        )
        .sort(pl.col("BinLeft").cast(pl.Float64))
    )


def extract_bin_left_right(dataf, *, column_bin):
    return (
        dataf
        .with_columns(
            pl.col(column_bin)
            .str.strip_prefix("[")
            .str.strip_suffix(")")
            .str.split(", ")
            .alias("BinLeftRight")
        )
        .with_columns(
            pl.col("BinLeftRight").list.get(0).alias("BinLeft"),
            pl.col("BinLeftRight").list.get(1).alias("BinRight")
        )
    )
