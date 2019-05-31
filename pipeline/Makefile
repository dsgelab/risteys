# Usage:
#   cd <data-dir>
#   make --makefile <path-to-this-Makefile>

code_path := $(dir ${MAKEFILE_LIST})

outputs := endpoint_efo.json indivs_sex.json aggregated_data.json count_by_sex.json

# Pseudo-targets
.PHONY: all clean

all: ${outputs}

clean:
	-rm -f ${outputs}

# Data file dependencies
endpoint_efo.json: endpoint_xrefs.json efo.owl
	python ${code_path}get_efo.py .

indivs_sex.json: FINNGEN_MINIMUM_DATA.txt
	python ${code_path}get_indivs_sex.py .

aggregated_data.json count_by_sex.json: FINNGEN_ENDPOINTS_longitudinal.txt indivs_sex.json
	python ${code_path}aggregate_by_endpoint.py $^ .
