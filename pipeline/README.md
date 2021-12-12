# Pipeline

## Requirements

- Python 3.6+

- Data files
  - `endpoint_doid_exact_names_ag2.tsv` from Tuomo, map endpoint to DOIDs
  - `efo.owl` from https://github.com/EBISPOT/efo/releases/

## Setup

Install the python packages listed in `requirements.txt`.

One way to do this is by using a Python virtual environment:

1. `python3 -m venv myvenv`

2. `source myvenv/bin/activate`

3. `pip install -r requirements.txt`

## Running

1. Make sure all the data files are in the same directory `$DATADIR` and the pipeline directory is at `$PIPELINEDIR`

2. `cd $DATADIR`

3. `make -f $PIPELINEDIR/Makefile -j 2`


Note that the Cox HR computations are not run part of the pipeline.
Instead, they are run with https://github.com/DataBiosphere/dsub[dsub].
Check the documentation in `surv_analysis.py` for more information.
