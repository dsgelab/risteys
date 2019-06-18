"""
Get a list of EFO ids for each endpoint.

Usage:
    python get_efo.py <path-to-data-directory>

Output: a JSON file with a mapping of endpoint name -> list of EFO ids
"""

import json
from csv import excel_tab
from pathlib import Path
from sys import argv

import pandas as pd
from pronto import Ontology

from log import logger


INPUT_ENDPOINT_FILE = "endpoint_doid_exact_names_ag2.tsv"
INPUT_ONTOLOGY_FILE = "efo.owl"
OUTPUT_FILE = "ontology.json"


def prechecks(input_endpoint_path, input_ontology_path, output_path):
    """Perform checks before running to fail earlier rather than later"""
    logger.info("Performing pre-checks")
    assert input_endpoint_path.exists()
    assert input_ontology_path.exists()
    assert not output_path.exists()


def main(data_directory):
    input_endpoint_path = data_directory / INPUT_ENDPOINT_FILE
    input_ontology_path = data_directory / INPUT_ONTOLOGY_FILE
    output_path = data_directory / OUTPUT_FILE
    prechecks(input_endpoint_path, input_ontology_path, output_path)

    endpoint_doids = map_endpoint_doids(input_endpoint_path)

    logger.info("Parsing ontology file to map EFO->[]DOIDS")
    path = str(input_ontology_path)  # 'Ontology' takes only str as input
    ontology = Ontology(path)

    efo_doids = map_efo_doids(ontology)
    endpoint_efos = map_endpoint_efos(endpoint_doids, efo_doids)
    endpoint_refs = get_endpoint_refs(ontology, endpoint_efos)

    with open(output_path, "x") as f:
        json.dump(endpoint_refs, f)


def map_endpoint_doids(endpoints_path):
    """Build a map of endpoint -> list of DOIDs"""
    logger.info("Mapping endpoint name to list of DOIDs")
    res = {}
    df = pd.read_csv(
        endpoints_path,
        dialect=excel_tab,
        usecols=["NAME", "best_doid"]
    )

    for elem in df.itertuples():
        name = elem.NAME
        doids = elem.best_doid

        if not pd.isna(doids):
            doids = doids.split(",")
            doids = set(map(lambda d: d.lstrip("DOID:"), doids))
            res[name] = doids

    return res


def map_efo_doids(ontology):
    """Build a map of EFO -> list of DOIDs from the ontology file"""
    logger.info("Mapping EFO -> list of DOIDs")
    res = {}

    for term in ontology:
        if term.id.startswith("EFO:"):
            efo = term.id.lstrip("EFO:")

            doids = term.other.get('xref', [])
            doids = filter(lambda x: x.startswith("DOID:"), doids)
            doids = map(lambda x: x.lstrip("DOID:"), doids)
            doids = set(doids)

            res[efo] = doids

    return res


def map_endpoint_efos(dict_endpoint_doids, dict_efo_doids):
    """For each endpoint, attribute the best EFO if any matches through DOIDs"""
    logger.info("Finding best EFO to attribute for each endpoint")
    res = {}

    for name, endpoint_doids in dict_endpoint_doids.items():
        # Build EFO scores -> (# matches, # non-matches)
        scores = {}
        for efo, efo_doids in dict_efo_doids.items():
            scores[efo] = score_efo(endpoint_doids, efo_doids)

        scores = sorted(scores.items(), key=lambda tupl: tupl[1])
        (best_efo, (matches, non_matches)) = scores[-1]
        if matches > 0:  # Don't attribute an EFO if non of the EFO have a match
            logger.debug(f"Assigning EFO {best_efo} to {name}: {matches} matches, {non_matches} non-matches")
            res[name] = best_efo
        else:
            logger.debug(f"No matching EFO for endpoint {name}")
            res[name] = None

    return res


def score_efo(endpoint_doids, efo_doids):
    """Compute a score for a match of two sets of DOIDs.

    Score is built with:
    - number of DOID that matches in the 2 sets
    - number of DOID attributed to the EFO but not the endpoint

    Sorting these, the last item is the best. It will have the maximum
    number of matches. In case of equality, the EFO with less non
    matching DOIDs will have a higher score.
    """
    matches = efo_doids.intersection(endpoint_doids)
    non_matches = efo_doids - endpoint_doids
    score = (len(matches), - len(non_matches))
    return score


def get_endpoint_refs(ontology, endpoint_efos):
    """Attribute information to an endpoint from the EFO ontology"""
    logger.info("Building map of endpoint -> refs")
    res = {}

    for endpoint, efo in endpoint_efos.items():
        if efo is not None:
            term = "EFO:" + efo
            term = ontology.get(term)

            description = f"{term.name}: {str(term.desc)}"

            xrefs = term.other.get('xref', [])
            doids = find_xrefs("DOID", xrefs)
            meshs = find_xrefs("MESH", xrefs)
            snomeds = find_xrefs("SCTID", xrefs)
        
            res[endpoint] = {
                "description": description,
                "EFO": [efo],
                "DOID": doids,
                "MESH": meshs,
                "SNOMED": snomeds,
            }
        else:
            res[endpoint] = {}

    return res


def find_xrefs(name, xrefs):
    """Return a list of ID for a given xref name in a term xrefs"""
    name = name + ":"
    res = filter(lambda x: x.startswith(name), xrefs)
    res = list(map(lambda x: x.lstrip(name), res))
    return res


if __name__ == '__main__':
    DATA_DIRECTORY = Path(argv[1])
    main(DATA_DIRECTORY)
