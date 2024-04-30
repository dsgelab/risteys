# copy results from non _EXALLC and non _EXMORE endpoints to their counterpart
# _EXALLC and _EXMORE endpoints that are core endpoints and not omitted from Risteys

library(readr)

# TODO: setwd to data directory first!
# check to be in correct dir
getwd()

# read in _EXALLC endpoints and make it a list 
endpoints_EXALLC <- read.csv("endpoints_EXALLC_core_not_omit_2_r10.csv", header = FALSE)
endpoints_EXALLC <-  endpoints_EXALLC$V1

# read in _EXMORE endpoints and make it a list 
endpoints_EXMORE <- read.csv("endpoints_EXMORE_core_not_omit_2_r10.csv", header = FALSE)
endpoints_EXMORE <- endpoints_EXMORE$V1

# read in FR results file 
    # key figures all
    # key figures index
    # age distrib
    # year distrib
    # cumulative incidence 
    # mortality baseline
    # mortality params
    # mortality counts

file_name <- "key_figures_all_2022-10-10.csv"
file_name <- "key_figures_index_2022-10-10.csv"
file_name <- "distribution_age_2022-10-10.csv"
file_name <- "distribution_year_2022-10-10.csv"
file_name <- "cumulative_incidence_2022-10-10.csv"
file_name <- "mortality_baseline_cumulative_hazard_2022-10-11.csv"
file_name <- "mortality_params_2022-10-11.csv"
file_name <- "mortality_counts_2022-10-11.csv"

file <- file_name
results <- original_results
new_results <- results[1,]

str(results)

  endpoint_list <- endpoints_EXALLC  
  suffix <- "_EXALLC"
###

file_list <- c(
  "key_figures_all_2022-10-10.csv",  
  "key_figures_index_2022-10-10.csv",
  "distribution_age_2022-10-10.csv",
  "distribution_year_2022-10-10.csv",
  "cumulative_incidence_2022-10-10.csv",
  "mortality_baseline_cumulative_hazard_2022-10-11.csv",
  "mortality_params_2022-10-11.csv",
  "mortality_counts_2022-10-11.csv"
  )


# function to create results for _EXALLC and _EXMORE endpoint by copying 
# the results from their counterpart endpoints that have the same definitions
append_results <- function (results, endpoint_list, suffix) {
  nrow_start <- nrow(results)
  n_unique_endp <- length(unique(results$endpoint))
  n_new_endpoints <- length(endpoint_list)
  n_unique_new_endp <- length(unique(endpoint_list))
  
  for (endpoint in endpoint_list){
    # create counterpart endpoint name by removing the _EXALLC or _EXMORE suffix
    endpoint_counterpart <- unlist(strsplit(endpoint, suffix, fixed = TRUE))
    
    # if counterpart endpoint is found in results file 
    # copy the row to output data frame and concatenate suffix to endpoint name
    if (endpoint_counterpart %in% results$endpoint){
      rows <- results[results$endpoint == endpoint_counterpart, ]
      new_name <- paste0(rows$endpoint,suffix)
      rows[, "endpoint"] <- new_name
      results <- rbind(results, rows)
    } else {
      print(paste("counterpart endpoint", endpoint, "not found from results file!"))
    }
  }
  
  # sanity checks
  # n of new endpoints in the data frame should be the same as n of endpoints in endpoint_list 
  if (length(unique(results$endpoint)) - n_unique_endp != n_unique_new_endp) {
    print("Number of endpoints to add does not match with the number of added unique endpoints!")
  }
  print(paste("Number of unique endpoints in the beginning:", n_unique_endp))
  print(paste("Number of endpoint rows in the beginning:", nrow_start))
  print(paste("Number of unique endpoints to be added:", n_new_endpoints))
  print(paste("Number of unique endpoints after adding endpoints:", length(unique(results$endpoint))))
  print(paste("Number of endpoint rows after adding endpoints:", nrow(results)))
  print(paste("Number of added unique endpoints:", length(unique(results$endpoint)) - n_unique_endp))
  
  return(results)
}

for (file in file_list) {
  
  print(paste("processing data in file", file))
  # read data in the results files as characters to avoid integer and scientific representation of floats
  original_results <- read_csv(file, col_types = cols(.default = "c"))
  print(str(original_results))
  
  # add _EXALLC and _EXMORE endpoints
  out_results <- append_results(original_results, endpoints_EXALLC, "_EXALLC") 
  out_results <- append_results(out_results, endpoints_EXMORE, "_EXMORE") 
  
  # save output data frame to a csv file
  name_start <- unlist(strsplit(file, ".csv", fixed = TRUE))
  out_filename <- paste0(name_start, "_with_EXALLC_EXMORE.csv")
  # quote = FALSE, na = "" to have expected data format without quotes and NA's as empty strings
  write.table(out_results, out_filename, sep = ",", row.names = FALSE, quote = FALSE, na = "")
  
  print("----------------------------------------------------------------------")
}

# end of the script