#!/usr/bin/env python3
"""
Compute drug scores related to a given endpoint.

Usage:
    python3 medication_stats_logit.py \
        <ENDPOINT> \                  # FinnGen endpoint for which to compute associated drug scores
        <PATH_FIRST_EVENTS> \         # Path to the first events file from FinnGen
        <PATH_DETAILED_LONGIT> \      # Path to the detailed longitudinal file from FinnGen
        <PATH_ENDPOINT_DEFINITIONS \  # Path to the endpoint definitions file from FinnGen
        <PATH_MINIMUM_INFO> \         # Path to the minimum file from FinnGen
        <OUTPUT_DIRECTORY>            # Path to where to put the output files

Outputs:
- <ENDPOINT>_scores.csv: CSV file with score and standard error for each drug
- <ENDPOINT>_counts.csv: CSV file which breakdowns drugs into their full ATC and counts how the
  number of individuals.
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import json
from collections import defaultdict

first_event_path = '/data/processed_data/endpointer/main/finngen_endpoints_04-09-2021_v3.densified_OMITs.txt'
info_path = '/data/notebooks/minimal_phenotype_file.csv'

df_fevent = pd.read_csv(first_event_path)

df_fevent = df_fevent.astype({
    "FINNGENID": np.object,
    "ENDPOINT": np.object,
    "AGE": np.float64,
    "YEAR": np.int64,
    "NEVT": np.int64,
})

dfsex = pd.read_csv(info_path, usecols=["FINREGISTRYID", "sex"])

# remove the only duplicate in the current version
dfsex = dfsex.drop(4976996)
# remove one line with NaN instead of an ID
dfsex = dfsex[dfsex['FINREGISTRYID'].notna()]
# remove all the null value in sex column
dfsex = dfsex[dfsex.sex.notna()]

dfsex = dfsex.astype({
    "FINREGISTRYID": np.object,
    "sex": "category",
})
# Perform one-hot encoding for SEX so it can be written to HDF
# without the slow format="table".
onehot = pd.get_dummies(dfsex["sex"])
dfsex = pd.concat([dfsex, onehot], axis=1)
dfsex = dfsex.drop("sex", axis=1)


def main(fg_endpoint, first_events, detailed_longit, endpoint_defs, minimum_info, output_scores, output_counts):
    """Compute a score for the association of a given drug to a FinnGen endpoint"""
    line_buffering = 1

    # File with drug scores
    scores_file = open(output_scores, "x", buffering=line_buffering)
    res_writer = csv.writer(scores_file)
    res_writer.writerow([
        "endpoint",
        "drug",
        "score",
        "stderr",
        "n_indivs",
        "pvalue"
    ])

    # Results of full-ATC drug counts
    counts_file = open(output_counts, "x", buffering=line_buffering)
    counts_writer = csv.writer(counts_file)
    counts_writer.writerow([
        "endpoint",
        "drug",
        "full_ATC",
        "count"
    ])

    # Load endpoint and drug data
    df_logit, endpoint_def = load_data(
        fg_endpoint,
        first_events,
        detailed_longit,
        endpoint_defs,
        minimum_info)
    is_sex_specific = pd.notna(endpoint_def.SEX)

    for drug in df_logit.ATC.unique():
        data_comp_logit(df_logit, fg_endpoint, drug, is_sex_specific, res_writer, counts_writer)

    scores_file.close()
    counts_file.close()

if __name__ == '__main__':
    main(
        fg_endpoint=getenv("FG_ENDPOINT"),
        first_events=Path(getenv("FIRST_EVENTS")),
        detailed_longit=Path(getenv("DETAILED_LONGIT")),
        endpoint_defs=Path(getenv("ENDPOINT_DEFS")),
        minimum_info=Path(getenv("MINIMUM_INFO")),
        output_scores=Path(getenv("OUTPUT_SCORES")),
        output_counts=Path(getenv("OUTPUT_COUNTS")),
    )
