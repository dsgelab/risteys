# Pipeline

The Risteys pipeline is used for generating aggregated data displayed on Risteys.

## Requirements

- Python 3.6+
- Python packages listed in `requirements.txt`
- Data files: 
  - Endpoint definitions dataset
  - Wide first events dataset
  - Minimal phenotype dataset
  - `endpoint_doind_exact_names_ag2.tsv` (FinnGen only)
  - [`efo.owl`](https://github.com/EBISPOT/efo/releases/) (FinnGen only)

## Setup

The required python packages can be installed using `conda` as follows:

```
conda create --name <env_name> --file requirements.txt
```

## Running

### FinnGen pipeline

1. Make sure all the data files are in the same directory `$DATADIR` and the pipeline directory is at `$PIPELINEDIR`

2. `cd $DATADIR`

3. `make -f $PIPELINEDIR/Makefile -j 2`

Note that the Cox HR computations are not run part of the pipeline.
Instead, they are run with https://github.com/DataBiosphere/dsub[dsub].
Check the documentation in `surv_analysis.py` for more information.

### FinRegistry pipeline

1. Make sure all the file paths in `config.py` match the location of the source data files.
2. `cd <project_root>/pipeline`
3. `python scripts/<file_name>`, e.g. `python scipts/finregistry_mortality_analysis.py`


## Running tests

Tests can be ran from the project root (`pipeline/`) as follows.

```
pytest test
```

If you want to suppress deprecation warnings (originating from `lifelines`), use the following for running the tests.

```
pytest test -W ignore::DeprecationWarning
```