from csv import writer as csv_writer
from pathlib import Path
from sys import argv
from time import time as now
import datetime
import numpy as np
import pandas as pd
from lifelines import CoxPHFitter
from lifelines.utils import ConvergenceError
from lifelines.utils import interpolate_at_times
import tqdm

first_event_path = '/data/processed_data/endpointer/main/finngen_endpoints_04-09-2021_v3.densified_OMITs.txt'
info_path = '/data/notebooks/mpf/minimal_phenotype_file.csv'
ep_path = '/data/processed_data/endpointer/main/FINNGEN_ENDPOINTS_DF8_Final_2021-06-21.xlsx'

STUDY_STARTS = 1998.0 #datetime.datetime(1998,1,1)  # inclusive
STUDY_ENDS = 2020.99 #datetime.datetime(2020,12,31)   # inclusive, using same number format as FinnGen data files

N_SUBCOHORT = 1_300_000
# Minimum number of individuals having both the endpoint and died,
# this must be > 5 to not be deemed as containing individual-level data.
MIN_INDIVS = 100

class NotEnoughIndividuals(Exception):
    pass

# Column names for lagged HR
LAG_COLS = {
    None: {
        "duration": "duration",
        "death": "death"
    },
    (5, 15): {
        "duration": "duration_15y",
        "death": "death_15y"
    },
    (1, 5): {
        "duration": "duration_5y",
        "death": "death_5y"
    },
    (0, 1): {
        "duration": "duration_1y",
        "death": "death_1y"
    }
}


# Used for HR re-computation
BCH_TIMEPOINTS = [0, 2.5, 5, 7.5, 10, 12.5, 15, 17.5, 20, 21.99]

def is_leap_year(year):
    """Determine whether a year is a leap year."""
    return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)

def calculate_dob_float(row):
    days_past = int(row.days_past)
    if is_leap_year(row.year_of_birth):
        days_total = 366
    else:
        days_total = 365
    return row.year_of_birth+days_past/days_total

def load_data(first_event_path, info_path, ep_path):
	# Get first events
	df_events = pd.read_csv(first_event_path)

	# Get sex and approximate birth date of each indiv
	df_info = pd.read_csv(info_path, usecols=["FINREGISTRYID", "date_of_birth", "sex"])

	# remove the duplicate
	df_info = df_info.drop(4976996)
	# remove one line with NaN instead of an ID
	df_info = df_info[df_info['FINREGISTRYID'].notna()]
	# remove all the null value in sex column
	df_info = df_info[df_info.sex.notna()]

	df_info["female"] = df_info.sex == 2.0 # 1 = male, 2 = female

	# calculate year float
	df_info["year_of_birth"] = pd.DatetimeIndex(df_info.date_of_birth).year
	df_info["days_past"] = pd.DatetimeIndex(df_info.date_of_birth).strftime('%j')
	df_info['BIRTH_TYEAR'] = df_info.apply(lambda row:calculate_dob_float(row), axis=1)

	###############3df_info = df_info.drop(columns=["sex", "date_of_birth"])

	# set age at start and end of study for each indiv
	df_info["START_AGE"] = STUDY_STARTS - df_info.BIRTH_TYEAR

	# add death age to df_info
	deaths = (
	    df_events.loc[df_events.ENDPOINT == "DEATH", ["FINNGENID", "AGE"]]
	    .rename(columns={"AGE": "DEATH_AGE"})
	)
	df_info = df_info.merge(deaths, left_on="FINREGISTRYID", right_on="FINNGENID", how="left")

	df_info["END_AGE"] = df_info.apply(
	    # We cannot simply use min() or max() here due to NaN, so we resort to an if-else
	    lambda r: r.DEATH_AGE if (r.BIRTH_TYEAR + r.DEATH_AGE) < STUDY_ENDS else (STUDY_ENDS - r.BIRTH_TYEAR),
	    axis="columns"
	)

	# Remove individuals that lived outside of the study time frame
	died_before_study = set(df_info.loc[df_info.END_AGE < df_info.START_AGE,"FINREGISTRYID"].unique())
	df_events = df_events.loc[~ df_events.FINNGENID.isin(died_before_study), :]
	df_info = df_info.loc[~ df_info.FINREGISTRYID.isin(died_before_study), :]

	born_after_study = set((df_info.BIRTH_TYEAR > STUDY_ENDS).index)
	df_events = df_events.loc[~ df_events.FINNGENID.isin(born_after_study), :]
	df_info = df_info.loc[~ df_info.FINREGISTRYID.isin(born_after_study), :]

	# add a column for outcome
	df_info['death_bool'] = ~df_info.DEATH_AGE.isna()

	# filter out all the individuals who are born after STUDY_START
	df_info = df_info[df_info.START_AGE >= 0] 

	# clean the dataframe
	df_info = df_info.drop(columns=['FINNGENID'])
	df_info = df_info.rename({'FINREGISTRYID':'FINNGENID'}, axis='columns')
	df_info = df_info[['FINNGENID','female','BIRTH_TYEAR','START_AGE','END_AGE','death_bool']]

	# get endpoints and if they are sex specified
	endpoints = pd.read_excel(ep_path, sheet_name='Sheet 1', usecols=['NAME','SEX'])  # 4632
	omited_eps = df_events.ENDPOINT.unique()
	endpoints = endpoints[endpoints.NAME.isin(omited_eps)]  # 3169

	return df_events, df_info, endpoints




