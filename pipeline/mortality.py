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

# number of individuals ramdomly selected from the cases and the full cohort
N_CASES = 250_000
N_COHORT = 500_000

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
	# if one is born after the study start date, set the start age as 0.0
	df_info["START_AGE"] = df_info.apply(lambda r: max(STUDY_STARTS - r.BIRTH_TYEAR, 0.0), axis=1)

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

	# # filter out all the individuals who are born after STUDY_START
	# df_info = df_info[df_info.START_AGE >= 0] 

	# clean the dataframe
	df_info = df_info.drop(columns=['FINNGENID'])
	df_info = df_info.rename({'FINREGISTRYID':'FINNGENID'}, axis='columns')
	df_info = df_info[['FINNGENID','female','BIRTH_TYEAR','START_AGE','END_AGE','death_bool']]

	# remove duplicates
	df_info = df_info.drop_duplicates()

	# get endpoints and if they are sex specified
	endpoints = pd.read_excel(ep_path, sheet_name='Sheet 1', usecols=['NAME','SEX'])  # 4632
	omited_eps = df_events.ENDPOINT.unique()
	# remove all the omited endpoints
	endpoints = endpoints[endpoints.NAME.isin(omited_eps)]  # 3169

	return df_events, df_info, endpoints

def init_csv(res_file):
    res_writer = csv_writer(res_file)
    res_writer.writerow([
        "endpoint",
        "lag_hr",
        "nindivs_prior_later",
        "absolute_risk",
        "endpoint_coef",
        "endpoint_se",
        "endpoint_hr",
        "endpoint_ci_lower",
        "endpoint_ci_upper",
        "endpoint_pval",
        "endpoint_zval",
        "endpoint_norm_mean",
        "year_coef",
        "year_se",
        "year_hr",
        "year_ci_lower",
        "year_ci_upper",
        "year_pval",
        "year_zval",
        "year_norm_mean",
        "sex_coef",
        "sex_se",
        "sex_hr",
        "sex_ci_lower",
        "sex_ci_upper",
        "sex_pval",
        "sex_zval",
        "sex_norm_mean",
        # bch: baseline cumulative hazard
        "bch",
        "bch_0",
        "bch_2.5",
        "bch_5",
        "bch_7.5",
        "bch_10",
        "bch_12.5",
        "bch_15",
        "bch_17.5",
        "bch_20",
        "bch_21.99"
    ])

    return res_writer


def prep_coxhr(endpoint, df_fevents, df_samples):
#     logger.info(f"Preparing data before Cox fitting for {endpoint.NAME}")

    df_fevents_ep = df_fevents[df_fevents.ENDPOINT == endpoint.NAME.tolist()[0]][['FINNGENID','AGE','DATE']]
    df_fevents_ep = df_fevents_t2d[df_fevents_t2d.DATE > 1998.0]
    df_fevents_ep = df_fevents_ep.rename(columns={"AGE": "ENDPOINT_AGE"}

    # Merge endpoint data with info data
    df_samples = df_info.merge(df_fevents_ep, on="FINNGENID", how="left")  # left join to keep individuals not having the endpoint

    # Define groups for the unexposed/exposed study
    exposed = set(df_fevents_ep.FINNGENID)
    unexp           = samples - exposed - cases
    unexp_death     = cases - exposed
    unexp_exp       = exposed - cases
    unexp_exp_death = exposed & cases
    assert len(samples) == (len(unexp) + len(unexp_death) + len(unexp_exp) + len(unexp_exp_death))

    # Check that we have enough individuals to do the study
    nindivs = len(unexp_exp_death)
    if nindivs < MIN_INDIVS:
        raise NotEnoughIndividuals(f"Not enough individuals having endpoint({endpoint.NAME}) and death: {nindivs} < {MIN_INDIVS}")
    elif len(unexp_exp) < MIN_INDIVS:
        raise NotEnoughIndividuals(f"Not enougth individuals in group: endpoint({endpoint.NAME}) + no death, {len(unexp_exp)} < {MIN_INDIVS}")

    # # Move endpoint to study start if it happened before the study
    # exposed_before_study = df_sample.ENDPOINT_AGE < df_sample.START_AGE
    # df_sample.loc[exposed_before_study, "ENDPOINT_AGE"] = df_sample.loc[exposed_before_study, "START_AGE"]

    # Unexposed
    df_unexp = df_samples.loc[df_samples.FINNGENID.isin(unexp), :].copy()
    df_unexp["duration"] = df_unexp.END_AGE - df_unexp.START_AGE
    df_unexp["endpoint"] = False
    df_unexp["death"] = False

    # Unexposed -> Death
    df_unexp_death = df_samples.loc[df_samples.FINNGENID.isin(unexp_death), :].copy()
    df_unexp_death["duration"] = df_unexp_death.END_AGE - df_unexp_death.START_AGE
    df_unexp_death["endpoint"] = False
    df_unexp_death["death"] = True

    # Unexposed -> Exposed: need time-window splitting
    df_unexp_exp = df_samples.loc[df_samples.FINNGENID.isin(unexp_exp), :].copy()
    # Phase 1: unexposed
    df_unexp_exp_p1 = df_unexp_exp.copy()
    df_unexp_exp_p1["duration"] = df_unexp_exp_p1.ENDPOINT_AGE - df_unexp_exp_p1.START_AGE
    df_unexp_exp_p1["endpoint"] = False
    df_unexp_exp_p1["death"] = False
    # Phase 2: exposed
    df_unexp_exp_p2 = df_unexp_exp.copy()
    df_unexp_exp_p2["endpoint"] = True
    for lag, cols in LAG_COLS.items():
        if lag is None:  # no lag HR
            duration = df_unexp_exp_p2.END_AGE - df_unexp_exp_p2.ENDPOINT_AGE
        else:
            _min_lag, max_lag = lag
            duration = df_unexp_exp_p2.apply(
                lambda r: min(r.END_AGE - r.ENDPOINT_AGE, max_lag),
                axis="columns"
            )
        df_unexp_exp_p2[cols["duration"]] = duration
        df_unexp_exp_p2[cols["death"]] = False

    # Unexposed -> Exposed -> Death: need time-window splitting
    df_unexp_exp_death = df_samples.loc[df_samples.FINNGENID.isin(unexp_exp_death), :].copy()
    # Phase 1: unexposed
    df_unexp_exp_death_p1 = df_unexp_exp_death.copy()
    df_unexp_exp_death_p1["duration"] = df_unexp_exp_death_p1.ENDPOINT_AGE - df_unexp_exp_death_p1.START_AGE
    df_unexp_exp_death_p1["endpoint"] = False
    df_unexp_exp_death_p1["death"] = False
    # Phase 2: exposed
    df_unexp_exp_death_p2 = df_unexp_exp_death.copy()
    df_unexp_exp_death_p2["endpoint"] = True
    for lag, cols in LAG_COLS.items():
        if lag is None:
            duration = df_unexp_exp_death_p2.END_AGE - df_unexp_exp_death_p2.ENDPOINT_AGE
            death = True
        else:
            min_lag, max_lag = lag
            duration = df_unexp_exp_death_p2.apply(
                lambda r: min(r.END_AGE - r.ENDPOINT_AGE, max_lag),
                axis="columns"
            )
            death_time = df_unexp_exp_death_p2.END_AGE - df_unexp_exp_death_p2.ENDPOINT_AGE
            death = (death_time >= min_lag) & (death_time <= max_lag)
        df_unexp_exp_death_p2[cols["duration"]] = duration
        df_unexp_exp_death_p2[cols["death"]] = death

#     logger.info("done preparing the data")
    return (
        df_unexp,
        df_unexp_death,
        df_unexp_exp_p1,
        df_unexp_exp_p2,
        df_unexp_exp_death_p1,
        df_unexp_exp_death_p2
    )


def main():
    start = datetime.datetime.now()

    # Load input data
    df_events, df_info, endpoints = load_data(first_event_path, info_path, ep_path)

    # define the samples
    # all the calculation will be done on basis of this df_sample
    subcohort = set(df_info.sample(n=N_COHORT).FINNGENID.tolist())
	cases = set(df_info[df_info.death_bool == True].sample(n=N_CASES).FINNGENID.tolist())
	samples = cases | subcohort

	df_samples = df_info[df_info.FINNGENID.isin(samples)]
	df_fevents = df_events[df_events.FINNGENID.isin(samples)]
    
	# Define samples for case-cohort design study.
	# Naming follows Johansson-16 paper.
	# full_cohort = set(df_events.FINNGENID)
	full_cohort = set(df_info.FINNGENID)
	full_cases = set(df_events.loc[df_events.ENDPOINT == "DEATH", "FINNGENID"])

    size = len(df_samples)
	non_cases = full_cohort - full_cases
	# cases_in_samples = cases
	non_cases_in_samples = samples - cases

	sampling_fraction_of_non_cases = len(non_cases_in_samples) / len(non_cases)
	weight_controls = 1 / sampling_fraction_of_non_cases

	sampling_fraction_of_cases = len(cases) / len(full_cases)
	weight_cases = 1 / sampling_fraction_of_cases

	# Assign case-cohort weight to each individual
	df_weights = pd.DataFrame({"FINNGENID": list(samples)})
	df_weights["weight"] = 1.0
	df_weights.loc[df_weights.FINNGENID.isin(cases), "weight"] = weight_cases
	df_weights.loc[df_weights.FINNGENID.isin(non_cases_in_samples), "weight"] = weight_controls
	df_samples = df_samples.merge(df_weights, on="FINNGENID")



    # Manually craft the JSON output given the 3 JSON strings we already have
    # logger.info(f"Writing out data to JSON in file {output_path}")
    output = f'{{"stats": {agg_stats}, "distrib_age": {distrib_age}, "distrib_year": {distrib_year}}}'
    # format date
    today = datetime.datetime.today().strftime("%Y-%m-%d")
    with open('finregistry_stats__'+today+'.json', "x") as f:
        f.write(output)

    end = datetime.datetime.now()
    print("Done. The time it took is "+str(end-start))

if __name__ == '__main__':
    main()


