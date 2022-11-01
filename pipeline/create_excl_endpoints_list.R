# Make a list of endpoints for which FinRegistry results are not shown in FR-FG Risteys

# As of FinnGen DF8 definitions and FR-FG Risteys R8 these endpoints were either
# omitted or had a different definition in FinRegistry data than in FinnGen data

# As of FinnGen DF10 definitions and FR-FG Risteys R10 excluded endpoints are
# omitted endpoints and "DEATH" that is no longer omitted endpoint but is
# unreliable in FinRegistry data.
# There are no endpoints with different definitions because for R10 FR-FG Risteys
# endpoints are run with same definition file and endpointter in both projects.
# Code related to these sections are just commented out, not removed, to allow
# easily returning that code if needed for later releases and to help understanding
# the application codebase that handles endpoints with different definitions.

# saves data frame as a csv file to the directory where script is run
# --> run from FinRegistry data directory and provide full path to the script

# columns in output file for FR-FG Risteys R8
# NAME: endpoint name
# EXCL: "excl_omitted" = omitted endpoint (OMIT == 1 | OMIT == 2),
      # "excl_diff_def" = different definition,
      # "excl_both" = both

# columns in output file for FR-FG Risteys R8
# NAME: endpoint name
# EXCL: "excl_omitted" = omitted endpoint (OMIT == 1 | OMIT == 2),
      # "excl_unreliable" = endpoint that is unreliable in FinRegistry data (DEATH)


# USAGE:
# Rscript path_to_create_excl_endpoints_list.R path_to_endpoint_definition_file
# for R10, the omitted endpoints are only shown in controls file so that is used as an input

library(dplyr)

args <- commandArgs(trailingOnly = TRUE)

if(length(args)  == 0) {
  stop("Path to input file need to be provided")
} else {
  path_to_definitions <-  args[1]
}

# endp_definitions <- read.csv(path_to_definitions) # R8
endp_definitions <- read.csv(path_to_definitions, sep = ";") # R10

print("head endp_definitions:")
print(head(endp_definitions))

# remove first column because it only contains explanations
# Controls file of R10 data doesn't contain unnecessary row
# endp_definitions <- slice(endp_definitions,2:nrow(endp_definitions))

# create a data frame of endpoints that are excluded:
# omitted or (R8:have different definition) and "DEATH" for R10

omitted <- filter(endp_definitions, OMIT==1 | OMIT ==2)

# NOTE, exclusion based on different definition is not done for R10 data
# NOTE, endpoints having values in OUTPAT_ICD are excluded because the version
# of endpointter used for creating R8 endpoints for FinRegistry incorrectly
# used ICPC2 as OUTPAT_ICD codes in some cases
#diff_def <- filter(endp_definitions, !is.na(endp_definitions$OUTPAT_ICD))

# endpoints that are omitted and have different definition
#excl_both <- filter(endp_definitions, !is.na(OUTPAT_ICD) & (OMIT==1 | OMIT==2))

# remove duplicates
#excl_omitted <- filter(omitted, !NAME %in% excl_both$NAME)
#excl_diff_def <- filter(diff_def, !NAME %in% excl_both$NAME)

# R10: add "DEATH" to the list of excluded endpoints
unreliable <- filter(endp_definitions, NAME=="DEATH")

# give value for each exclusion reason.
#excl_omitted$FR_EXCL <- "excl_omitted" # 1486 endpoints in FinRegistry data for R8 Risteys
#excl_diff_def$FR_EXCL <- "excl_diff_def" # 53 endpoints in R8
#excl_both$FR_EXCL <- "excl_both" # 25 endpoints in R8

omitted$FR_EXCL <- "excl_omitted" # 1937 endpoints in R10
unreliable$FR_EXCL <- "excl_unreliable" # # 1 endpoint in R10

# combine
# excluded_endpoints <- rbind(excl_omitted, excl_diff_def, excl_both) # 1564 endpoints in R8
excluded_endpoints <- rbind(omitted, unreliable) # 1938 endpoints in R10

# keep only needed columns
excluded_endpoints <- select(excluded_endpoints,  NAME,  FR_EXCL)

# save data
write.csv(excluded_endpoints, file = "excluded_endpoints_FR_Risteys_R10.csv", row.names = FALSE)

### end of the script ###
