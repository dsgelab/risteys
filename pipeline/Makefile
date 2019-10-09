# USAGE:
#   cd <data-dir>
#   make --makefile <path-to-this-Makefile>

code_path := $(dir ${MAKEFILE_LIST})

outputs := ontology.json FINNGEN_ENDPOINTS_longitudinal_QCed.csv dense_first_events.csv input.hdf5 stats.hdf5 stats.json filtered_pairs.csv

#
# PSEUDO-TARGETS
#
.PHONY: all clean

all: ${outputs}

clean:
	-rm -f ${outputs}

#
# DATA FILE DEPENDENCIES
#
ontology.json: endpoint_doid.tsv efo.owl
	python ${code_path}get_efo.py .

# Here the 3 files are checked for QC, but only the longitudinal file is rewritten
FINNGEN_ENDPOINTS_longitudinal_QCed.csv: FINNGEN_PHENOTYPES.txt FINNGEN_ENDPOINTS_longitudinal.txt FINNGEN_MINIMUM_DATA.txt
	python ${code_path}qc.py .

# The QCed longitudinal file is a dependency, as we want the QC step
# to be done before doing this step.
# However, the QCed longitudinal file is NOT an input of the script of
# this step.
dense_first_events.csv: FINNGEN_ENDPOINTS_longitudinal_QCed.csv FINNGEN_PHENOTYPES.txt
	python ${code_path}densify_first_events.py .

input.hdf5: dense_first_events.csv FINNGEN_ENDPOINTS_longitudinal_QCed.csv FINNGEN_MINIMUM_DATA.txt  Endpoint_definitions_FINNGEN_ENDPOINTS.tsv COV_PHENO.txt
	python ${code_path}build_input_hdf.py .

stats.hdf5: input.hdf5
	python ${code_path}aggregate_by_endpoint.py .

stats.json: stats.hdf5
	python ${code_path}stats_to_json.py .

filtered_pairs.csv: input.hdf5
	python ${code_path}surv_endpoints.py .
