import pandas as pd
from risteys_pipeline.finregistry.cumulative_incidence import green_distribution


def test_green_distribution_early_onset():
    df = pd.DataFrame(
        {"endpoint": ["A"] * 10, "age": [11, 11, 22, 22, 22, 22, 22, 22, 22, 22]}
    )
    dist = (
        df.assign(age_group=pd.cut(df["age"], [0, 10, 20, 30, 40, 50]))
        .groupby(["endpoint", "age_group"])
        .size()
    )
    res = green_distribution(dist)
    expected = [
        {"left": 0, "right": 10, "count": 0},
        {"left": 10, "right": 30, "count": 10},
        {"left": 30, "right": 40, "count": 0},
        {"left": 40, "right": 50, "count": 0}
    ]
    assert res == expected

def test_green_distribution_late_onset():
    df = pd.DataFrame(
        {"endpoint": ["A"] * 10, "age": [33, 33, 44, 44, 44, 44, 44, 44, 44, 44]}
    )
    dist = (
        df.assign(age_group=pd.cut(df["age"], [0, 10, 20, 30, 40, 50]))
        .groupby(["endpoint", "age_group"])
        .size()
    )
    res = green_distribution(dist)
    expected = [
        {"left": 0, "right": 10, "count": 0},
        {"left": 10, "right": 20, "count": 0},
        {"left": 20, "right": 30, "count": 0},
        {"left": 30, "right": 50, "count": 10}
    ]
    assert res == expected

def test_green_distribution_early_onset_trailing_individual_level_data():
    # Bug described here: https://github.com/dsgelab/risteys/issues/122
    df = pd.DataFrame(
        {"endpoint": ["A"] * 10, "age": [11, 11, 22, 22, 22, 22, 22, 22, 22, 33]}
    )
    dist = (
        df.assign(age_group=pd.cut(df["age"], [0, 10, 20, 30, 40, 50]))
        .groupby(["endpoint", "age_group"])
        .size()
    )
    res = green_distribution(dist)
    expected = [
        {"left": 0, "right": 10, "count": 0},
        {"left": 10, "right": 40, "count": 10},
        {"left": 40, "right": 50, "count": 10}
    ]
    assert res == expected
