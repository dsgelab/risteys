"""Mortality analysis"""

import pandas as pd

from risteys_pipeline.config import MIN_SUBJECTS_PERSONAL_DATA
from risteys_pipeline.log import logger
from risteys_pipeline.finregistry.survival_analysis import (
    MIN_SUBJECTS_SURVIVAL_ANALYSIS,
    add_exposure,
    build_survival_dataset,
    get_exposed,
    survival_analysis,
)

N_DIGITS = 4


def mortality_analysis(endpoint, df_mortality, all_cases):
    """
    Mortality analysis

    Args:
        endpoint (str): name of the endpoint
        all_cases (DataFrame): dataset with cases for all endpoints
        cohort (DataFrame): cohort for sampling controls

    Returns:
        TBD
    """
    logger.debug(endpoint)

    params = None
    bch = None

    exposed = get_exposed(endpoint, all_cases, df_mortality)
    n_exposed = exposed.shape[0]

    # Check that the dataset can include enough exposed cases and non-cases
    if n_exposed > 2 * MIN_SUBJECTS_SURVIVAL_ANALYSIS:

        df_mortality_ = df_mortality.copy()
        df_mortality_ = add_exposure(exposed, df_mortality_)

        # Check if endpoint is sex-specific
        # TODO: this does not work, the weights are not correct!
        mean_sex = df_mortality_.loc[df_mortality_["exposure"] == 1, "female"].mean()
        sex_male = mean_sex < 0.1
        sex_female = mean_sex > 0.9

        if sex_male | sex_female:
            df_mortality_ = df_mortality_.loc[
                df_mortality_["female"] == round(mean_sex)
            ]
            model = survival_analysis(df_mortality_, "age", drop=["female"])
        else:
            model = survival_analysis(df_mortality_, "age")

        if model is not None:
            # Calculate baseline cumulative hazard by age group
            bch = model.baseline_cumulative_hazard_
            bch = bch.rename(
                columns={"baseline cumulative hazard": "baseline_cumulative_hazard"}
            )
            bch = bch.reset_index().rename(columns={"index": "age"})
            bch["age"] = round(bch["age"])
            bch = bch.groupby("age").mean()

            # Calculate number of events by age group
            counts = df_mortality.loc[df_mortality["outcome"] == 1].reset_index(
                drop=True
            )
            counts["age"] = round(counts["stop"] - counts["birth_year"])
            counts = counts.groupby("age")["outcome"].sum().reset_index()
            counts = counts.rename(columns={"outcome": "n_events"})

            # Filter out personal data
            bch = bch.merge(counts, on="age", how="left")
            bch = bch.loc[bch["n_events"] >= MIN_SUBJECTS_PERSONAL_DATA]
            bch = bch.drop(columns=["n_events"])
            bch = bch.round(N_DIGITS)
            bch["endpoint"] = endpoint

            # Get means
            means = df_mortality_[["birth_year", "female", "exposure"]].mean()

            # Extract parameters
            params = model.summary[["coef", "coef lower 95%", "coef upper 95%", "p"]]
            params = params.reset_index()
            params["endpoint"] = endpoint
            params = params.merge(
                means.rename("mean"), left_on="covariate", right_index=True
            )
            params = params.rename(
                columns={
                    "coef lower 95%": "ci95_lower",
                    "coef upper 95%": "ci95_upper",
                    "p": "p_value",
                }
            )
            cols = ["coef", "ci95_lower", "ci95_upper", "p_value", "mean"]
            params[cols] = params[cols].round(4)


    return (params, bch)


if __name__ == "__main__":
    import pandas as pd
    from risteys_pipeline.finregistry.load_data import load_data
    from risteys_pipeline.finregistry.survival_analysis import (
        get_cohort,
        prep_all_cases,
    )
    from risteys_pipeline.finregistry.write_data import get_output_filepath
    from multiprocessing import Pool, get_context
    from functools import partial
    from tqdm import tqdm

    N_PROCESSES = 35

    endpoints, minimal_phenotype, first_events = load_data()

    cohort = get_cohort(minimal_phenotype)
    all_cases = prep_all_cases(first_events, cohort)

    df_mortality = build_survival_dataset("DEATH", None, cohort, all_cases)

    # Exclude persons not in the sampled data
    all_cases_ = all_cases.loc[
        all_cases["personid"].isin(df_mortality["personid"].unique())
    ]
    all_cases_ = all_cases_.reset_index(drop=True)

    # Exclude endpoints with too little persons
    endpoints_ = (
        all_cases_.groupby("endpoint")
        .filter(lambda x: x["personid"].nunique() > MIN_SUBJECTS_SURVIVAL_ANALYSIS * 2)[
            "endpoint"
        ]
        .unique()
    )

    # For testing
    #endpoints_ = endpoints_[:20]

    endpoints_ = endpoints_[endpoints_ != "DEATH"]
    all_cases_ = all_cases_.loc[all_cases_["endpoint"].isin(endpoints_)]
    all_cases_ = all_cases_.reset_index(drop=True)

    n_endpoints = len(endpoints_)
    args_iter = iter(endpoints_)
    partial_mortality = partial(
        mortality_analysis, df_mortality=df_mortality, all_cases=all_cases_
    )

    with get_context("spawn").Pool(processes=N_PROCESSES) as pool:
        result = list(
            tqdm(
                pool.imap_unordered(
                    partial_mortality, args_iter
                ),
                total=n_endpoints,
            )
        )

    params = [x[0] for x in result if x[0] is not None]
    bch = [x[1] for x in result if x[1] is not None]

    params = pd.concat(params, axis=0, ignore_index=True)
    bch = pd.concat(bch, axis=0, ignore_index=True)

    logger.info("Writing output to file")

    params_output_file = get_output_filepath("mortality_params", "csv")
    bch_output_file = get_output_filepath("mortality_baseline_cumulative_hazard", "csv")

    params.to_csv(params_output_file, index=False)
    bch.to_csv(bch_output_file, index=False)

