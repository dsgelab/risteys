# Make a list of endpoints for which FinRegistry results are not shown in FR-FG Risteys

# As of FinnGen DF8 definitions and FR-FG Risteys R8 these endpoints were either
# omitted or had a different definition in FinRegistry data than in FinnGen data

# As of FinnGen DF10 definitions and FR-FG Risteys R10 excluded endpoints are
# - omitted endpoints 
# - "DEATH" that is no longer omitted endpoint but is unreliable in FinRegistry data.
# - endpoints where in the definition file value of column "HD_ICD_10_ATC" is "ANY"
# - "F5_SAD"

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

# columns in output file for FR-FG Risteys R10
# NAME: endpoint name
# EXCL: "excl_omitted" = omitted endpoint (OMIT == 1 | OMIT == 2),
      # "excl_not_available" = DEATH, F5_SAD, endpoints with HD_ICD_10_ATC == "ANY"


# USAGE:
# R8: Rscript path_to_create_excl_endpoints_list.R path_to_endpoint_definition_file
# endpoint omit information was in definition file

# for R10, the omitted endpoints are only shown in controls file so that is used as an input as well
# Rscript path_to_create_excl_endpoints_list.R path_to_endpoint_control_file path_to_endpoint_definition_file

library(dplyr)

args <- commandArgs(trailingOnly = TRUE)

if(length(args)  != 2) {
  stop("Path to input files need to be provided")
} else {
  path_to_controls <-  args[1]
  path_to_definitions <-  args[2]
}

# endp_definitions <- read.csv(path_to_definitions) # R8
endp_controls <- read.csv(path_to_controls, sep = ";")
endp_definitions_r10 <- read.csv(path_to_definitions, sep = ";") # R10

print("head endp_controls:")
print(head(endp_controls))
print(str(endp_controls))

print("head endp_definitions_r10:")
print(head(endp_definitions_r10))
print(str(endp_definitions_r10))

#### get excluded endpoints from control file: omitted endpoints & death ####

# remove first column because it only contains explanations
# Controls file of R10 data doesn't contain unnecessary row
# endp_definitions <- slice(endp_definitions,2:nrow(endp_definitions))

# create a data frame of endpoints that are excluded:
# omitted or (R8:have different definition) and "DEATH" for R10

omitted <- filter(endp_controls, OMIT==1 | OMIT ==2)

print(paste("Number of omitted endpoints:", nrow(omitted)))

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
unreliable <- filter(endp_controls, NAME=="DEATH")
print(paste("Number of unreliable endpoints (death):", nrow(unreliable)))

# give value for each exclusion reason.
#excl_omitted$FR_EXCL <- "excl_omitted" # 1486 endpoints in FinRegistry data for R8 Risteys
#excl_diff_def$FR_EXCL <- "excl_diff_def" # 53 endpoints in R8
#excl_both$FR_EXCL <- "excl_both" # 25 endpoints in R8

omitted$FR_EXCL <- "excl_omitted" # 1937 endpoints in R10
unreliable$FR_EXCL <- "excl_not_available" # # 1 endpoint in R10

# combine
# excluded_endpoints <- rbind(excl_omitted, excl_diff_def, excl_both) # 1564 endpoints in R8
excluded_endpoints <- rbind(omitted, unreliable) # 1938 endpoints in R10

# keep only needed columns
excluded_endpoints <- select(excluded_endpoints,  NAME,  FR_EXCL)

#### get excluded endpoints from definition file: HD_ICD_10_ATC == "ANY" &  F5_SAD ####
excluded_atc <- filter(endp_definitions_r10, HD_ICD_10_ATC == "ANY")
excluded_atc$FR_EXCL <- "excl_not_available"

print(paste("Number of excluded_atc endpoints:", nrow(excluded_atc))) #112 endpoints in R10

# R10: add "F5_SAD" to the list of excluded endpoints
excluded_F5_SAD <- filter(endp_definitions_r10, NAME=="F5_SAD")
excluded_F5_SAD$FR_EXCL <- "excl_not_available"

print(paste("Number of excluded_F5_SAD endpoints:", nrow(excluded_F5_SAD)))

# combine
excluded <- rbind(excluded_atc, excluded_F5_SAD)

# keep only needed columns
excluded <- select(excluded,  NAME,  FR_EXCL)

#### combine excluded endpoints selected from control and definition files ####
excluded_endpoints_all <- rbind(excluded_endpoints, excluded)

print(paste("Number of all excluded endpoints:", nrow(excluded_endpoints_all)))

#### save data ####
out_file_name <- "excluded_endpoints_FR_Risteys_R10.csv"
write.csv(excluded_endpoints_all, file = out_file_name, row.names = FALSE)

print(paste("results wrote to file:", out_file_name))
### end of the script ###
