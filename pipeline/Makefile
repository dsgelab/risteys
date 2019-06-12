# Usage:
#   cd <data-dir>
#   make --makefile <path-to-this-Makefile>

code_path := $(dir ${MAKEFILE_LIST})

outputs := endpoint_efo.json input.hdf5 stats.hdf5 stats.json

# Pseudo-targets
.PHONY: all clean

all: ${outputs}

clean:
	-rm -f ${outputs}

# Data file dependencies
endpoint_efo.json: endpoint_xrefs.json efo.owl
	python ${code_path}get_efo.py .

input.hdf5: FINNGEN_ENDPOINTS_longitudinal.txt FINNGEN_MINIMUM_DATA.txt
	python ${code_path}build_input_hdf.py .

stats.hdf5: input.hdf5
	python ${code_path}aggregate_by_endpoint.py .

stats.json: stats.hdf5
	python ${code_path}stats_to_json.py .
