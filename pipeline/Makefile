# Usage:
#   DATA_DIRECTORY=<path-to-data-dir> make

.PHONY: all clean

all: endpoint_efo.json indivs_sex.json

clean:
	-rm *.json

# Data file dependencies
endpoint_efo.json: ${DATA_DIRECTORY}/endpoint_xrefs.json ${DATA_DIRECTORY}/efo.owl
	python get_efo.py ${DATA_DIRECTORY}

indivs_sex.json: ${DATA_DIRECTORY}/FINNGEN_MINIMUM_DATA.txt
	python get_indivs_sex.py ${DATA_DIRECTORY}
