# Make a list of endpoints that are omitted or 
# have different definition in FinRegistry data than in FinnGen data 
# saves data frame as a csv file to the directory where script is run
# --> run from FinRegistry data directory and provide full path to the script

# columns in output file
# NAME: endpoint name
# EXCL: 1 = omitted endpoint, 2 = different definition, 3 = both

# USAGE:
# Rscript path_to_create_excl_endpoints_list.R path_to_endpoint_definition_file 

library(dplyr)

args <- commandArgs(trailingOnly = TRUE)

if(length(args)  == 0) {
  stop("Path to input file need to be provided")
} else {
  path_to_definitions <-  args[1]
}

endp_definitions <- read.csv(path_to_definitions)

# remove first column because it only contains explanations
endp_definitions <- slice(endp_definitions,2:nrow(endp_definitions)) 

# create a data frame of endpoints that are excluded: omitted or have different definition

# consider only endpoints with OMIT value 1 because 
# endpoints with OMIT value 2  are not in FinnGen sandbox -> not in Risteys
omitted <- filter(endp_definitions, OMIT==1)

# NOTE, endpoints having values in OUTPAT_ICD are excluded because the version
# of endpointter used for creating R8 endpoints for FinRegistry incorrectly  
# used ICPC2 as OUTPAT_ICD codes in some cases
diff_def <- filter(endp_definitions, !is.na(endp_definitions$OUTPAT_ICD))

# endpoints that are omitted and have different definition
excl_both <- filter(endp_definitions, !is.na(OUTPAT_ICD) & OMIT==1)

# remove duplicates
excl_omitted <- filter(omitted, !NAME %in% excl_both$NAME)
excl_diff_def <- filter(diff_def, !NAME %in% excl_both$NAME)

# give value for each exclusion reason. 
excl_omitted$FR_EXCL <- "excl_omitted" # 1478 endpoints
excl_diff_def$FR_EXCL <- "excl_diff_def" # 53 endpoints
excl_both$FR_EXCL <- "excl_both" # 25 endpoints

# combine
excluded_endpoints <- rbind(excl_omitted, excl_diff_def, excl_both)

# keep only needed columns
excluded_endpoints <- select(excluded_endpoints,  NAME,  FR_EXCL) 

# save data
write.csv(excluded_endpoints, file = "excluded_endpoints.csv", row.names = FALSE)

### end of the script ###
