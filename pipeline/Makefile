# Usage:
#   cd <data-dir>
#   make --makefile <path-to-this-Makefile>

code_path := $(dir ${MAKEFILE_LIST})

outputs := ontology.json input.hdf5 stats.hdf5 stats.json filtered_pairs.csv

# Pseudo-targets
.PHONY: all clean

all: ${outputs}

clean:
	-rm -f ${outputs}

# Data file dependencies
ontology.json: endpoint_doid.tsv efo.owl
	python ${code_path}get_efo.py .

qc.hdf5: FINNGEN_PHENOTYPES.txt FINNGEN_ENDPOINTS_longitudinal.txt FINNGEN_MINIMUM_DATA.txt
	python ${code_path}qc.py .

input.hdf5: qc.hdf5 Endpoint_definitions_FINNGEN_ENDPOINTS.tsv COV_PHENO.txt
	python ${code_path}build_input_hdf.py .

stats.hdf5: input.hdf5
	python ${code_path}aggregate_by_endpoint.py .

stats.json: stats.hdf5
	python ${code_path}stats_to_json.py .

filtered_pairs.csv: input.hdf5
	python ${code_path}surv_endpoints.py .
