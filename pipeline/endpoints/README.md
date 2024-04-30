# Risteys Pipeline

The Risteys pipeline is used for generating aggregated data displayed on the [Risteys portal](https://risteys.finregistry.fi/). The aggregated data covers the following:
- Key figures (number of persons, period prevalence, median age)
- Age and year distributions
- Cumulative incidence function
- Mortality analysis

The methods are described in [Risteys documentation](https://risteys.finregistry.fi/documentation). If you have any questions or feedback, feel free to [contact us](https://airtable.com/shrTzTwby7JhFEqi6) or [open an issue](https://github.com/dsgelab/risteys/issues/new) on GitHub.

## Getting started

### Requirements

- Conda
- Requirements listed in `requirements.txt`

### Setup

The required python packages can be installed using `conda` as follows:

```
conda create --name <env_name> --file requirements.txt
```

The `risteys_pipeline` module can be installed from the project root (`pipeline`) as follows:

```
conda activate <env_name>
cd pipeline
python setup.py install
```

### Running tests

Tests can be ran from the project root (`pipeline`) as follows.

```
pytest test
```

If you want to suppress deprecation warnings, use the following for running the tests.

```
pytest test -W ignore::DeprecationWarning
```

## Usage

1. Make sure all the file paths in `config.py` match the location of the source data files.

2. Move to the `pipeline` directory.
```
cd <project_root>/pipeline
```

3. Run a script.
```
python risteys_pipeline/<file_name>
# e.g. python risteys_pipeline/run_mortality.py
```

The Risteys pipeline is organized as a Python module. You may use parts of the pipeline by importing the functions.
```python
from risteys_pipeline.sample import calculate_sampling_weight
```


Note that the Cox HR computations are not run part of the pipeline.
Instead, they are run with [dsub](https://github.com/DataBiosphere/dsub).
Check the documentation in `surv_analysis.py` for more information.

## Source data

| Dataset | File | Source | Notes |
| ------- | ---- | ------ | ----- |
| Endpoint definitions | `+Endpoints_Controls_FINNGEN_ENDPOINTS_DF?_Final_?_corrected.xlsx+` | Clinical team |
| Minimal phenotype | `+finngen_R?_minimum_?.txt.gz+` | e-Science team |
| Wide first events | `+finngen_R?_endpoint_?.txt.gz+` | e-Science team | Used to generate the long-format first events dataset using `wide_to_long_endpoint_first_events.py`
| Detailed longitudinal events | `+finngen_R?_detailed_longitudinal_?.txt.gz+` | e-Science team | FinnGen only
| Filter of individuals | `R?_COV_PHENO_V?.txt.gz` | Analysis team, e-Science team | FinnGen only
| Endpoint priority list | FinnGen priority phenotypes (sheet: priority) (Google Sheet) | Clinical team | FinnGen only. Extract the `Code` column to a file.
| Endpoint info columns | - | - | FinnGen only. Includes columns `FINNGENID`, `FU_END_AGE` and `SEX` extracted from the wide first-events file

All files need to be formatted to CSV or feather for processing in the Risteys pipeline. The `?` in file names denotes a placeholder for versioning information.

## Data flow

#### Endpoint ontology (FinnGen only)

TBD

#### Key figures

```mermaid
  graph LR;
    id0[/Wide first events/] -.-> wide_to_long_endpoint_first_events.py
    wide_to_long_endpoint_first_events.py -.-> id3
    id1[/Endpoint definitions/] --> run_key_figures.py
    id2[/Minimal phenotype/] --> run_key_figures.py
    id3[/Long-format first events/] --> run_key_figures.py
    run_key_figures.py --> id4[/key_figures.csv/]
```

#### Age and year distributions

```mermaid
  graph LR;
    id0[/Wide first events/] -.-> wide_to_long_endpoint_first_events.py
    wide_to_long_endpoint_first_events.py -.-> id3
    id1[/Endpoint definitions/] --> run_distributions.py
    id2[/Minimal phenotype/] --> run_distributions.py
    id3[/Long-format first events/] --> run_distributions.py
    run_distributions.py --> id4[/distribution_age.csv/]
    run_distributions.py --> id5[/distribution_year.csv/]
```

#### Cumulative incidence function

```mermaid
  graph LR;
    id0[/Wide first events/] -.-> wide_to_long_endpoint_first_events.py
    wide_to_long_endpoint_first_events.py -.-> id3
    id1[/Endpoint definitions/] --> run_cumulative_incidence.py
    id2[/Minimal phenotype/] --> run_cumulative_incidence.py
    id3[/Long-format first events/] --> run_cumulative_incidence.py
    run_cumulative_incidence.py --> id4[/cumulative_incidence.csv/]
```

#### Mortality analysis

```mermaid
  graph LR;
    id0[/Wide first events/] -.-> wide_to_long_endpoint_first_events.py
    wide_to_long_endpoint_first_events.py -.-> id3
    id1[/Endpoint definitions/] --> run_mortality.py
    id2[/Minimal phenotype/] --> run_mortality.py
    id3[/Long-format first events/] --> run_mortality.py
    run_mortality.py --> id4[/mortality_params.csv/]
    run_mortality.py --> id5[/mortality_cbh.csv/]
    run_mortality.py --> id6[/mortality_counts.csv/]
```

#### Endpoint-endpoint survival analysis (FinnGen only)

```mermaid
  graph LR;
    id1[/Endpoint definitions/] --> surv_select_endpoint_pairs.py
    id2[/Priority endpoints/] --> surv_select_endpoint_pairs.py
    id3[/Correlations/] --> surv_select_endpoint_pairs.py
    id4[/Wide first events/] --> wide_to_long_endpoint_first_events.py
    wide_to_long_endpoint_first_events.py --> id6[/Long-format first events/]
    surv_select_endpoint_pairs.py --> id7[/Selected endpoint pairs/]
    id6 --> surv_analysis.py
    id7 --> surv_analysis.py
    id8[/Minimal phenotype/] --> surv_analysis.py
    surv_analysis.py --> id5[/surv_analysis.csv/]
```

#### Medication stats (FinnGen only)

```mermaid
  graph LR;
    id1[/Endpoint definitions/] --> medication_stats_logit.py
    id2[/Minimal phenotype/] --> medication_stats_logit.py
    id3[/Wide first events/] --> medication_stats_logit.py
    id4[/Detailed longitudinal events/] --> medication_stats_logit.py
    id5[/ENDPOINT/] --> medication_stats_logit.py
    medication_stats_logit.py --> id6[/ENDPOINT_scores.csv/]
    medication_stats_logit.py --> id7[/ENDPOINT_counts.csv/]

```
