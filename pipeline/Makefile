# Usage:
#   cd <data-dir>
#   make --makefile <path-to-this-Makefile>

code_path := $(dir ${MAKEFILE_LIST})

outputs := ontology.json input.hdf5 stats.hdf5 stats.json

# Pseudo-targets
.PHONY: all clean

all: ${outputs}

clean:
	-rm -f ${outputs}

# Data file dependencies
ontology.json: endpoint_doid.tsv efo.owl
	python ${code_path}get_efo.py .

input.hdf5: Endpoint_definitions_FINNGEN_ENDPOINTS.tsv FINNGEN_ENDPOINTS_longitudinal.txt FINNGEN_MINIMUM_DATA.txt COV_PHENO.txt
	python ${code_path}build_input_hdf.py .

stats.hdf5: input.hdf5
	python ${code_path}aggregate_by_endpoint.py .

stats.json: stats.hdf5
	python ${code_path}stats_to_json.py .
