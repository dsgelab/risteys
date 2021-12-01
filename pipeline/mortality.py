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

	# remove duplicates
	df_events = df_events.drop_duplicates()
	df_info = df_info.drop_duplicates()
	# remove one line with NaN instead of an ID
	df_info = df_info[df_info['FINREGISTRYID'].notna()]
	# remove all the null value in sex column
	df_info = df_info[df_info.sex.notna()]

	df_info["female"] = df_info.sex == 2.0 # 1 = male, 2 = female

	# calculate year float
	df_info["year_of_birth"] = pd.DatetimeIndex(df_info.date_of_birth).year
	df_info["days_past"] = pd.DatetimeIndex(df_info.date_of_birth).strftime('%j')
	df_info['BIRTH_TYEAR'] = df_info.apply(lambda row:calculate_dob_float(row), axis=1)

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
	df_info['death'] = ~df_info.DEATH_AGE.isna()

	# # filter out all the individuals who are born after STUDY_START
	# df_info = df_info[df_info.START_AGE >= 0] 

	# clean the dataframe
	df_info = df_info.drop(columns=['FINNGENID'])
	df_info = df_info.rename({'FINREGISTRYID':'FINNGENID'}, axis='columns')
	df_info = df_info[['FINNGENID','female','BIRTH_TYEAR','START_AGE','END_AGE','death']]

	# get endpoints and if they are sex specified
	endpoints = pd.read_excel(ep_path, sheet_name='Sheet 1', usecols=['NAME','SEX'])  # 4632
	omited_eps = df_events.ENDPOINT.unique()
	# remove all the omited endpoints
	endpoints = endpoints[endpoints.NAME.isin(omited_eps)]  # 3169

	'''
	N_COHORT, N_CASES are currently defined as gloable varibles
	'''

	# define the samples
    # all the calculation will be done on basis of this df_sample
    subcohort = set(df_info.sample(n=N_COHORT).FINNGENID.tolist())
	cases = set(df_info[df_info.death == True].sample(n=N_CASES).FINNGENID.tolist())
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

	# assign case-cohort weight to each individual
	df_samples["weight"] = 1.0
	df_samples.loc[df_samples.death_bool == True, "weight"] = weight_cases
	df_samples.loc[df_samples.death_bool == False, "weight"] = weight_controls

	# remove duplicates
	df_samples = df_samples.drop_duplicates()
	df_fevents = df_fevents.drop_duplicates()
	endpoints = endpoints.drop_duplicates()

	return df_fevents, df_samples, endpoints

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

# Method 1: remove all the events that happened before study_starts

def prep_coxhr(endpoint, df_fevents, df_samples):
    # logger.info(f"Preparing data before Cox fitting for {endpoint.NAME}")

    df_fevents_ep = df_fevents[df_fevents.ENDPOINT == endpoint.NAME.tolist()[0]]
    df_fevents_ep = df_fevents_ep[df_fevents_ep.DATE > 1998.0][['FINNGENID','AGE']]
    df_fevents_ep = df_fevents_ep.rename(columns={"AGE": "ENDPOINT_AGE"})

    # Merge endpoint data with info data
    df_samples = df_samples.merge(df_fevents_ep, on="FINNGENID", how="left")  # left join to keep individuals not having the endpoint
    df_samples = df_samples.rename(columns={"death_bool": "death"})
    
    # Define groups for the unexposed/exposed study
    exposed = set(df_fevents_ep.FINNGENID)
    unexp           = df_samples[(~df_samples.FINNGENID.isin(exposed))&(df_samples.death == False)]#samples - exposed - cases
    unexp_death     = df_samples[(~df_samples.FINNGENID.isin(exposed))&(df_samples.death == True)]#cases - exposed
    unexp_exp       = df_samples[(df_samples.FINNGENID.isin(exposed))&(df_samples.death == False)]#exposed - cases
    unexp_exp_death = df_samples[(df_samples.FINNGENID.isin(exposed))&(df_samples.death == True)]#exposed & cases
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
    unexp["duration"] = unexp.END_AGE - unexp.START_AGE
    unexp["endpoint"] = False

    # Unexposed -> Death
    unexp_death["duration"] = unexp_death.END_AGE - unexp_death.START_AGE
    unexp_death["endpoint"] = False

    # Unexposed -> Exposed: need time-window splitting
    # Phase 1: unexposed
    unexp_exp_p1 = unexp_exp.copy()
    unexp_exp_p1["duration"] = unexp_exp_p1.ENDPOINT_AGE - unexp_exp_p1.START_AGE
    unexp_exp_p1["endpoint"] = False
    # Phase 2: exposed
    unexp_exp_p2 = unexp_exp.copy()
    unexp_exp_p2["endpoint"] = True
    for lag, cols in LAG_COLS.items():
        if lag is None:  # no lag HR
            duration = unexp_exp_p2.END_AGE - unexp_exp_p2.ENDPOINT_AGE
        else:
            _min_lag, max_lag = lag
            duration = unexp_exp_p2.apply(
                lambda r: min(r.END_AGE - r.ENDPOINT_AGE, max_lag),
                axis="columns"
            )
        unexp_exp_p2[cols["duration"]] = duration
        unexp_exp_p2[cols["death"]] = False

    # Unexposed -> Exposed -> Death: need time-window splitting
    # Phase 1: unexposed
    unexp_exp_death_p1 = unexp_exp_death.copy()
    unexp_exp_death_p1["duration"] = unexp_exp_death_p1.ENDPOINT_AGE - unexp_exp_death_p1.START_AGE
    unexp_exp_death_p1["endpoint"] = False
    unexp_exp_death_p1["death"] = False
    # Phase 2: exposed
    unexp_exp_death_p2 = unexp_exp_death.copy()
    unexp_exp_death_p2["endpoint"] = True
    for lag, cols in LAG_COLS.items():
        if lag is None:
            duration = unexp_exp_death_p2.END_AGE - unexp_exp_death_p2.ENDPOINT_AGE
            death = True
        else:
            min_lag, max_lag = lag
            duration = unexp_exp_death_p2.apply(
                lambda r: min(r.END_AGE - r.ENDPOINT_AGE, max_lag),
                axis="columns"
            )
            death_time = unexp_exp_death_p2.END_AGE - unexp_exp_death_p2.ENDPOINT_AGE
            death = (death_time >= min_lag) & (death_time <= max_lag)
        unexp_exp_death_p2[cols["duration"]] = duration
        unexp_exp_death_p2[cols["death"]] = death

#     logger.info("done preparing the data")
    return unexp,unexp_death,unexp_exp_p1,unexp_exp_p2,unexp_exp_death_p1,unexp_exp_death_p2

# 
def prep_lifelines(cols, unexp,unexp_death,unexp_exp_p1,unexp_exp_p2,unexp_exp_death_p1,unexp_exp_death_p2):
#     logger.info("Preparing lifelines dataframes")

    # Rename lagged HR columns
    col_duration = cols["duration"]
    col_death = cols["death"]
    keep_cols_p2 = [col_duration, "endpoint", "BIRTH_TYEAR", "female", col_death, "weight"]
    unexp_exp_p2 = (
        df_unexp_exp_p2.loc[:, keep_cols_p2]
        .rename(columns={col_duration: "duration", col_death: "death"})
    )
    unexp_exp_death_p2 = (
        unexp_exp_death_p2.loc[:, keep_cols_p2]
        .rename(columns={col_duration: "duration", col_death: "death"})
    )

    # Re-check that there are enough individuals to do the study,
    # since after setting the lag some individuals might not have the
    # death outcome anymore.
    nindivs, _ =  unexp_exp_death_p2.loc[unexp_exp_death_p2.endpoint & unexp_exp_death_p2.death, :].shape
    if nindivs < MIN_INDIVS:
        raise NotEnoughIndividuals(f"not enough individuals with lag")

    # Concatenate the data frames together
    keep_cols = ["duration", "endpoint", "BIRTH_TYEAR", "female", "death", "weight"]
    df_lifelines = pd.concat([
        unexp.loc[:, keep_cols],
        unexp_death.loc[:, keep_cols],
        unexp_exp_p1.loc[:, keep_cols],
        unexp_exp_p2,
        unexp_exp_death_p1.loc[:, keep_cols],
        unexp_exp_death_p2],
        ignore_index=True)

#     logger.info("done preparing lifelines dataframes")
    return nindivs, df_lifelines


def bch_at(df, time):
    try:
        res = df.loc[time, "baseline cumulative hazard"]
    except KeyError:
        # Index of the BCH dataframe are floats, which may not be exact values, so we check for the closest one
        res = interpolate_at_times(df, [time])[0]
    return res

def main():
    start = datetime.datetime.now()

    # Load input data
    df_fevents, df_samples, endpoints = load_data(first_event_path, info_path, ep_path)

    # Prepare output file
    line_buffering = 1
	res_file = open('output.csv', "w", buffering=line_buffering)
	res_writer = init_csv(res_file)

	# File that keep tracks of how much time was spent on each endpoint
	timings_file = open('timings.csv', "w", buffering=line_buffering)
	timings_writer = csv_writer(timings_file)
	timings_writer.writerow(["endpoint", "lags_computed", "time_seconds"])

	for _, endpoint in tqdm.tqdm(endpoints.iterrows()):
	    time_start = now()
	    lags_computed = 0
	    try:
	    	# Define four different groups of individuals
			unexp, unexp_death, unexp_exp_p1, unexp_exp_p2, unexp_exp_death_p1, unexp_exp_death_p2 = prep_coxhr(endpoint, df_fevents, df_samples)
	        

	        for lag, cols in LAG_COLS.items():
	#             logger.info(f"Setting HR lag to: {lag}")
	            nindivs, df_lifelines = prep_lifelines(
			                    {"duration": "duration_15y","death": "death_15y"},
			                    unexp, unexp_death, unexp_exp_p1, unexp_exp_p2, unexp_exp_death_p1, unexp_exp_death_p2
			                )
				df_lifelines = df_lifelines.round(2)

				# Fit Cox model
				cph = CoxPHFitter()

				cph.fit(
				    df_lifelines,
				    duration_col="duration",
				    event_col="death",
				    # For the case-cohort study we need weights and robust errors:
				    weights_col="weight",
				    robust=True
				)

				# Compute absolute risk
				# Method 1: Mean age of the whole population is 1969.86 ~1970
				# Compare different generations: 1970, 1980, 1990, 2000
			    mean_indiv = {
			        "BIRTH_TYEAR": [1959.0],
			        "endpoint": [True],
			        "female": [0.5]
			    }

			        if is_sex_specific:
			        mean_indiv.pop("female")

			    if lag is None:
			        predict_at = STUDY_ENDS - STUDY_STARTS
			        lag_value = None
			    else:
			        _min_lag, max_lag = lag
			        predict_at = max_lag
			        lag_value = max_lag

			    surv_probability = cph.predict_survival_function(
			        pd.DataFrame(mean_indiv),
			        times=[predict_at]
			    ).values[0][0]
			    absolute_risk = 1 - surv_probability

			    norm_mean = cph._norm_mean
			    # Get values out of the fitted model
			    endp_coef = cph.params_["endpoint"]
			    endp_se = cph.standard_errors_["endpoint"]
			    endp_hr = np.exp(endp_coef)
			    endp_ci_lower = np.exp(endp_coef - 1.96 * endp_se)
			    endp_ci_upper = np.exp(endp_coef + 1.96 * endp_se)
			    endp_pval = cph.summary.p["endpoint"]
			    endp_zval = cph.summary.z["endpoint"]
			    endp_norm_mean = norm_mean["endpoint"]

			    year_coef = cph.params_["BIRTH_TYEAR"]
			    year_se = cph.standard_errors_["BIRTH_TYEAR"]
			    year_hr = np.exp(year_coef)
			    year_ci_lower = np.exp(year_coef - 1.96 * year_se)
			    year_ci_upper = np.exp(year_coef + 1.96 * year_se)
			    year_pval = cph.summary.p["BIRTH_TYEAR"]
			    year_zval = cph.summary.z["BIRTH_TYEAR"]
			    year_norm_mean = norm_mean["BIRTH_TYEAR"]

			    if not is_sex_specific:
			        sex_coef = cph.params_["female"]
			        sex_se = cph.standard_errors_["female"]
			        sex_hr = np.exp(sex_coef)
			        sex_ci_lower = np.exp(sex_coef - 1.96 * sex_se)
			        sex_ci_upper = np.exp(sex_coef + 1.96 * sex_se)
			        sex_pval = cph.summary.p["female"]
			        sex_zval = cph.summary.z["female"]
			        sex_norm_mean = norm_mean["female"]
			    else:
			        sex_coef = np.nan
			        sex_se = np.nan
			        sex_hr = np.nan
			        sex_ci_lower = np.nan
			        sex_ci_upper = np.nan
			        sex_pval = np.nan
			        sex_zval = np.nan
			        sex_norm_mean = np.nan

			    # Save the baseline cumulative hazard (bch)
			    df_bch = cph.baseline_cumulative_hazard_

			    baseline_cumulative_hazard = bch_at(df_bch, predict_at)

			    bch_values = {}
			    for time in BCH_TIMEPOINTS:
			        bch_values[time] = bch_at(df_bch, time)

			    # Save values
			    res_writer.writerow([
			        endpoint.NAME,
			        lag_value,
			        nindivs,
			        absolute_risk,
			        endp_coef,
			        endp_se,
			        endp_hr,
			        endp_ci_lower,
			        endp_ci_upper,
			        endp_pval,
			        endp_zval,
			        endp_norm_mean,
			        year_coef,
			        year_se,
			        year_hr,
			        year_ci_lower,
			        year_ci_upper,
			        year_pval,
			        year_zval,
			        year_norm_mean,
			        sex_coef,
			        sex_se,
			        sex_hr,
			        sex_ci_lower,
			        sex_ci_upper,
			        sex_pval,
			        sex_zval,
			        sex_norm_mean,
			        baseline_cumulative_hazard,
			        bch_values[0],
			        bch_values[2.5],
			        bch_values[5],
			        bch_values[7.5],
			        bch_values[10],
			        bch_values[12.5],
			        bch_values[15],
			        bch_values[17.5],
			        bch_values[20],
			        bch_values[21.99]
			    ])
	            
	            lags_computed += 1
	    except NotEnoughIndividuals as exc:
	        
	        
	        print(exc)
	#         logger.warning(exc)
	    except ConvergenceError as exc:
	        print(exc)
	#         logger.warning(f"Failed to run Cox.fit():\n{exc}")
	    finally:
	        endpoint_time = now() - time_start
	        timings_writer.writerow([endpoint.NAME, lags_computed, endpoint_time])

	timings_file.close()
	res_file.close()

    end = datetime.datetime.now()
    print("Done. The time it took is "+str(end-start))

if __name__ == '__main__':
    main()


