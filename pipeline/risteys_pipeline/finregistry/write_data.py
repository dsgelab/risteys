"""Helper functions for writing data to files"""

import json
import numpy as np
from collections import defaultdict


def distribution_to_dict(dist):
    """
    Transform distributions from a DataFrame to a Python dict.

    The output format is as follows:

    {
        "ENDPOINT_1": {
		    "all": [[[0, 10], 0000], [[10, 20], 0000], ...],
		    "female": ...,
		    "male": ...
        },
        "ENDPOINT_2": {
            "all": ...
            "female": ...,
            "male": ...
        },
        ...
    }

    Args:
        dist (DataFrame): DataFrame to be transformed. Must include the following columns:
        `sex` with values in ["all", "male", "female"],
        `left`, `right`, `count`

    Returns:
        res (dict): Distribution in dictionary format
    """

    res = defaultdict(dict)
    dist = dist.replace({np.nan: None, np.NINF: None, np.PINF: None})

    for (endpoint, df) in dist.groupby("endpoint"):
        endpoint_dist = {"all": [], "female": [], "male": []}
        df = df.sort_values("left", na_position="first")
        for _, row in df.iterrows():
            bin = [[row["left"], row["right"]], row["count"]]
            endpoint_dist[row["sex"]].append(bin)
        res[endpoint] = endpoint_dist

    return res


def summary_stats_to_json(key_figures, dist_age, dist_year):
    """
    Transform summary stats from DataFrames to JSON format

    Args:
        key_figures: key figures dataset, output of compute_key_figures()
        dist_age: age distributions dataset, output of compute_distribution()
        dist_year: year distribution dataset, output of compute_distribution()

    Returns: 
        res (str): summary stats in JSON format
    """
    key_figures = key_figures.set_index("endpoint").to_json(orient="index")
    dist_age = json.dumps(distribution_to_dict(dist_age))
    dist_year = json.dumps(distribution_to_dict(dist_year))
    res = f'{{"stats": {key_figures}, "distrib_age": {dist_age}, "distrib_year": {dist_year}}}'

    return res

