"""Functions for computing key figures"""

import numpy as np
import pandas as pd
from risteys_pipeline.log import logger
from risteys_pipeline.config import MIN_SUBJECTS_PERSONAL_DATA


def compute_key_figures(first_events, minimal_phenotype, index_persons=False):
    """
    Compute the following key figures for each endpoint:
        - number of individuals
        - unadjusted prevalence (%)
        - median age at first event (years)

    The numbers are calculated for males, females, and all.

    Args:
        first_events (DataFrame): first events dataframe
        minimal_phenotype(DataFrame): minimal phenotype dataframe
        index_persons (bool): compute key figures for index persons only (True) or everyone (False)

    Returns:
        kf (DataFrame): key figures dataframe with the following columns:
        endpoint, 
        nindivs_female, nindivs_male, nindivs_all, 
        median_age_male, median_age_all,
        prevalence_female, prevalence_male, prevalence_all
    """
    logger.info(
        "Computing key figures" + (" for index persons" if index_persons else "")
    )

    mp = minimal_phenotype.copy()
    fe = first_events.copy()

    # Only include index_persons if specified
    if index_persons:
        mp = mp.loc[mp["index_person"] == True].reset_index(drop=True)
        fe = fe.loc[fe["index_person"] == True].reset_index(drop=True)

    # Calculate the total number of individuals
    n_total = {
        "female": sum(mp["female"] == True),
        "male": sum(mp["female"] == False),
        "unknown": sum(mp["female"].isnull()),
    }

    # Calculate key figures by endpoint and sex
    kf = (
        fe.assign(
            sex=fe["female"].replace({True: "female", False: "male", np.nan: "unknown"})
        )
        .groupby(["endpoint", "sex"])
        .agg({"personid": "count", "age": "median"})
        .rename(columns={"personid": "nindivs_", "age": "median_age_"})
        .fillna({"nindivs_": 0})
        .reset_index()
    )
    kf["prevalence_"] = kf["nindivs_"] / kf["sex"].replace(n_total)
    kf["n_endpoint"] = kf.groupby("endpoint")["nindivs_"].transform("sum")
    kf["w"] = kf["nindivs_"] / kf["n_endpoint"]

    # Calculate key figures by endpoint for all individuals
    kf_all = (
        kf.groupby("endpoint")
        .agg(
            {
                "nindivs_": "sum",
                "median_age_": lambda x: np.average(x, weights=kf.loc[x.index, "w"]),
                "prevalence_": lambda x: np.average(x, weights=kf.loc[x.index, "w"]),
            }
        )
        .reset_index()
        .assign(sex="all")
    )

    # Drop rows with sex=unknown
    kf = kf.loc[kf["sex"] != "unknown"].reset_index(drop=True)

    # Combine the two datasets
    kf = pd.concat([kf, kf_all])

    # Drop redundant columns
    kf = kf.drop(columns=["w", "n_endpoint"])

    # Remove personal data
    cols = ["nindivs_", "median_age_", "prevalence_"]
    kf.loc[kf["nindivs_"] < MIN_SUBJECTS_PERSONAL_DATA, cols,] = np.nan

    # Pivot and flatten hierarchical columns
    kf = kf.pivot(index="endpoint", columns="sex").reset_index()
    kf.columns = ["".join(col).strip() for col in kf.columns.values]

    return kf


if __name__ == "__main__":
    from risteys_pipeline.finregistry.load_data import load_data
    from risteys_pipeline.finregistry.write_data import get_output_filepath

    endpoints, minimal_phenotype, first_events = load_data()

    kf_all = compute_key_figures(first_events, minimal_phenotype, index_persons=False)
    kf_index_persons = compute_key_figures(
        first_events, minimal_phenotype, index_persons=True
    )

    kf_all.to_csv(get_output_filepath("key_figures_all", "csv"))
    kf_index_persons.to_csv(get_output_filepath("key_figures_index", "csv"))
