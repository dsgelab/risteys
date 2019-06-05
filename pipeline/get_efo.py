"""
Get a list of EFO ids for each endpoint.

Usage:
    python get_efo.py <path-to-data-directory>

Output: a JSON file with a mapping of endpoint name -> list of EFO ids
"""

import json
from collections import defaultdict
from itertools import chain
from pathlib import Path
from sys import argv

from pronto import Ontology

from log import logger


INPUT_ENDPOINT_FILE = "endpoint_xrefs.json"
INPUT_ONTOLOGY_FILE = "efo.owl"
OUTPUT_FILE = "endpoint_efo.json"


def prechecks(data_directory):
    """Perform checks before running to fail earlier rather than later"""
    logger.info("Performing pre-checks")
    assert (data_directory / INPUT_ENDPOINT_FILE).exists()
    assert (data_directory / INPUT_ONTOLOGY_FILE).exists()
    assert not Path(OUTPUT_FILE).exists()


def main(data_directory):
    prechecks(data_directory)

    endpoint_doids = map_endpoint_doids(data_directory)
    doid_efos = map_doid_efos(data_directory)
    endpoint_efos = map_endpoint_efos(endpoint_doids, doid_efos)

    with open("endpoint_efo.json", "x") as f:
        json.dump(endpoint_efos, f)


def map_endpoint_doids(data_directory):
    """Build a map of endpoint -> list of DOIDs"""
    logger.info("Mapping endpoint name to list of DOIDs")
    endpoints_path = data_directory / INPUT_ENDPOINT_FILE
    with open(endpoints_path) as f:
        endpoints = json.load(f)
    endpoint_doids = {ee: xrefs.get("DOID", []) for ee, xrefs in endpoints.items()}
    return endpoint_doids


def map_doid_efos(data_directory):
    """Build a map of DOID -> list of EFOs"""
    logger.info("Mapping DOID to list of EFOs")
    # Load the EFO ontology
    ontology_path = data_directory / INPUT_ONTOLOGY_FILE
    ontology = Ontology(str(ontology_path))
    doid_efos = defaultdict(list)

    # Look for EFO:* terms in the ontology
    for term in ontology:
        if term.id.startswith("EFO:"):
            efo = term.id.replace("EFO:", "")

            # Get the associated DOIDs with this EFO
            doids = term.other.get('xref', [])
            doids = filter(lambda x: x.startswith("DOID:"), doids)
            doids = map(lambda x: x.replace("DOID:", ""), doids)
            doids = list(doids)

            # Associate the current EFO to each DOID (reverse-mapping)
            for doid in doids:
                doid_efos[doid].append(efo)

    return doid_efos


def map_endpoint_efos(endpoint_doids, doid_efos):
    """Build a map of Endpoint->EFOs by linking them through DOIDs"""
    logger.info("Mapping endpoint to EFOs")
    res = {}

    for endpoint, doids in endpoint_doids.items():
        efos = (doid_efos.get(doid) for doid in doids)
        efos = filter(lambda d: d is not None, efos)  # filter out DOID not found
        efos = chain.from_iterable(efos)  # flatten the list of lists into a simple list
        efos = set(efos)  # remove duplicates
        efos = list(efos)  # can't output sets in JSON, so converting to a list
        res[endpoint] = efos

    return res


if __name__ == '__main__':
    data_directory = Path(argv[1])
    main(data_directory)
