"""
Merge the XREFs of two JSON output files into one.

Usage:
    python merge_xref_efo_clean.py [--debug] <json-file-endpoint-xrefs> <json-file-efo-clean> > output.json

Needs the JSON output of two scripts that extracted XREFs information:
1. script 'endpoint_xrefs.py' that linked Endpoints to XREFs from the
   'doid.obo' file.
2. Andrea's script that linked Endpoints to XREFs from the 'efo.obo'
   file.  This script provides 2 information not in the first one:
   EFO_CLEAN and DESCRIPTION.
"""

import json
import logging
from sys import argv


def main(path_doid, path_efo_clean):
    """Output the merge of the 2 given JSON files with XREFs."""
    with open(path_doid) as f:
        doid = json.load(f)
    with open(path_efo_clean) as f:
        efo_clean = json.load(f)

    efo_clean = restructure(efo_clean)

    res = doid
    for endpoint, efo_clean_xrefs in efo_clean.items():
        if endpoint not in res:
            logging.debug(f"getting {endpoint} data from <json-file-efo-clean>")
            res[endpoint] = efo_clean_xrefs
        else:
            # Merge the endpoint xrefs from the 2 sources
            logging.debug(f"merging data for endpoint {endpoint}")
            doid_xrefs = res[endpoint]
            for xref, efo_clean_values in efo_clean_xrefs.items():
                if xref in doid_xrefs:
                    # Merge the values
                    logging.debug(f"both files have this xref, merging values for endpoint {endpoint} for xref {xref}")
                    values = set(doid_xrefs[xref])
                    values.update(efo_clean_values)
                    values = list(values)
                    res[endpoint][xref] = values
                else:
                    logging.debug(f"data for {endpoint}: {xref} not in <json-file-endpoint-xrefs>, adding as is from <json-file-efo-clean>")
                    res[endpoint][xref] = efo_clean_values


    print(json.dumps(res))


def restructure(efo_clean):
    """Restructure the efo_clean data so each XREF points to a list and not single value."""
    res = {}

    for endpoint, xrefs in efo_clean.items():
        consistent_xrefs = {}
        for name, values in xrefs.items():
            if isinstance(values, list):
                consistent_xrefs[name] = values
            else:
                logging.debug(f"values are not list {endpoint}: {name}: {values}")
                consistent_xrefs[name] = [values]
        res[endpoint] = consistent_xrefs

    return res


if __name__ == '__main__':
    # Check if in debug mode
    try:
        argv.remove("--debug")
    except ValueError:
        logging.basicConfig(level="INFO")
    else:
        logging.basicConfig(level="DEBUG")

    path_doid = argv[1]
    path_efo_clean = argv[2]

    main(path_doid, path_efo_clean)
