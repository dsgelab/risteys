library(rjson)
library(ontologyIndex)
library(stringr)

json_data <- fromJSON(file="/Users/aganna/Desktop/endpoint_xrefs.json")

efo <- get_OBO("/Users/aganna/Desktop/efo.obo", propagate_relationships = "is_a", extract_tags = "everything")
doid <- get_OBO("/Users/aganna/Desktop/doid.obo", propagate_relationships = "is_a", extract_tags = "everything")

property_value_with_gwas <- efo$property_value[grep("gwas:trait",efo$property_value)]

ext_SNOMEDCT <- lapply(property_value_with_gwas,function(x){gsub("SNOMEDCT:","",str_extract(x,"SNOMEDCT: ?([0-9]+)"))}) # 
ext_SNOMEDCT <- lapply(ext_SNOMEDCT, function(x) unique(x[!is.na(x)]))
ext_SNOMEDCT <- ext_SNOMEDCT[lapply(ext_SNOMEDCT,length)>0]
ext_SNOMEDCT <- ext_SNOMEDCT[grepl("EFO",names(ext_SNOMEDCT))]

ext_DOID <- lapply(property_value_with_gwas,function(x){gsub("DOID:","",str_extract(x,"DOID: ?([0-9]+)"))})
ext_DOID <- lapply(ext_DOID, function(x) unique(x[!is.na(x)]))
ext_DOID <- ext_DOID[lapply(ext_DOID,length)>0]
ext_DOID <- ext_DOID[grepl("EFO",names(ext_DOID))]



json_data_EDIT <- json_data
all_EFO_names <- gsub("EFO:","",names(property_value_with_gwas))

for (endpoint in names(json_data))
{
  endpoint_temp <- json_data[[endpoint]]

  # Add a new category with description
  doid_temp <- doid$def[gsub("DOID:","",doid$id) %in% endpoint_temp$DOID]
  if (all(is.na(doid_temp)))
  {
    endpoint_temp[['DESCRIPTION']] <- "No definition available"
  }else
  {
    doid_temp <- gsub('\"',"",gsub("\\[[^\\]]*\\]", "", doid_temp, perl=TRUE))
    doid_temp <- doid_temp[!is.na(doid_temp)][1:3]
    attr(doid_temp,"names") <- NULL                 
    endpoint_temp[['DESCRIPTION']] <- doid_temp[!is.na(doid_temp)]
  }

  # Match DOID if in the efo.obo
   a <- gsub("EFO:","", names(ext_DOID[unlist(lapply(ext_DOID, function(x) any(x %in% endpoint_temp$DOID)))]))
  
  # Match SNOMEDCT if in the efo.obo
  if (any(names(endpoint_temp)=="SNOMEDCT_US_2018_03_01"))
  {
    b <- gsub("EFO:","", names(ext_SNOMEDCT[unlist(lapply(ext_SNOMEDCT, function(x) any(x %in% endpoint_temp$SNOMEDCT_US_2018_03_01)))]))
  }
  
  # Add EFO if EFO from the .json has GWAS data
  c <- ifelse(endpoint_temp$EFO %in% all_EFO_names,endpoint_temp$EFO,NA)
  
  # Clear EFO_CLEAN by removing missing or non-match
  if (length(unique(c(a,b,c)))>0)
  {endpoint_temp[['EFO_CLEAN']] <- unique(c(a,b,c))}
  
  json_data_EDIT[[endpoint]] <- endpoint_temp
}


write(toJSON(json_data_EDIT),file="/Users/aganna/Desktop/endpoint_xrefs_description_efo_clean.json")
