"""
Attribute "xref"s to Endpoint through related DOIDs.

Usage:
    python endpoint_xrefs.py [--debug] <endpoints-doid-file> <doid-xref-file> > output.json

Given the following data files:
- mapping of Endpoint to DOID ids (from Tuomo Kiiskinen)
- mapping of DOID to xref (from Human Disease Ontology project [1])
link the Endpoint to their xref.

An xref is a reference to a resource such as: MESH, SNOMED_CT, UMLS, etc.

[1] https://github.com/DiseaseOntology/HumanDiseaseOntology/
"""

import json
import logging
from collections import defaultdict
from sys import argv


def main(path_endpoints, path_xrefs):
    """Outputs a JSON map from Endpoint to XREFs."""
    with open(path_endpoints) as f:
        endpoints = f.readlines()
    endpoints = map(lambda l: l.strip(), endpoints)

    with open(path_xrefs) as f:
        xrefs = f.read()

    endpoint_doids = map_endpoint_doids(endpoints)
    doid_xrefs = map_doid_xrefs(xrefs)
    endpoint_xrefs = map_endpoint_xrefs(endpoint_doids, doid_xrefs)
    print(json.dumps(endpoint_xrefs))


def map_endpoint_doids(endpoints):
    """Return a map of Endpoint -> DOID ids, given lines from the endpoint file."""
    res = {}
    # Get the column numbers for columns of interest
    header = next(endpoints)
    splits = header.split("\t")
    logging.debug(f"headers: {splits}")

    col_name = splits.index("NAME")
    col_doids = splits.index("best_doid")

    logging.debug(f"colum indexes: name {col_name}; doid {col_doids}")

    for line in endpoints:  # we already skipped the header with "next(enpdoints)"
        splits = line.split("\t")
        name = splits[col_name]
        doids = splits[col_doids]

        if doids == "NA":
            logging.info(f"Endpoint doesn't have a corresponding DOID: {name}")
        else:
            doids = doids.split(",")
            doids = map(lambda doid: doid.lstrip("DOID:"), doids)
            doids = list(doids)
            res[name] = doids

        if len(doids) > 5:
            logging.warning(f"Endpoints has {len(doids)} > 5 DOIDs: {name}")

    return res


def map_doid_xrefs(xrefs):
    """Return a map of DOID -> XREF list by parsing the given OBO file.

    The OBO file must have DOID as id and XREFs as term attributes.
    """
    res = {}
    tag_doid = "id: DOID:"
    tag_xref = "xref: "

    for block in term_blocks(xrefs):
        doid = None
        for line in block:
            if line.startswith(tag_doid):
                doid = line.lstrip(tag_doid)
                res[doid] = []
            elif line.startswith(tag_xref):
                xref = line.lstrip(tag_xref)
                res[doid].append(xref)

    return res


def term_blocks(xrefs):
    """Parses the doid-xrefs file and yield its [Term] blocks."""
    for block in xrefs.split("\n\n"):
        if block.startswith("[Term]"):
            block = block.split("\n")
            yield block


def map_endpoint_xrefs(endpoint_doid, doid_xrefs):
    """Link Endpoint to xrefs through DOID."""
    res = {}
    for endpoint, doids in endpoint_doid.items():
        logging.debug(f"Looking xrefs for endpoint: {endpoint}")
        logging.debug(f"doid list: {doids}")

        # 1. Get deduplicated XREFs
        xrefs = set()
        for doid in doids:
            xrefs.update(doid_xrefs[doid])
        logging.debug(f"xrefs set: {xrefs}")

        # 2. Put XREFs into their category (ex: UMLS:[C0040412,C0392494], OMIM:[137400])
        endpoint_xrefs = defaultdict(list)
        xrefs = map(lambda xref: xref.split(":"), xrefs)
        for [category, xref] in xrefs:
            endpoint_xrefs[category].append(xref)

        # 3. Add the DOID as an XREF
        endpoint_xrefs["DOID"] = doids

        res[endpoint] = endpoint_xrefs

    return res


if __name__ == '__main__':
    # Check if in debug mode
    try:
        argv.remove("--debug")
    except ValueError:
        pass  # debug flag not provided, nothing to do
    else:
        logging.basicConfig(level="DEBUG")

    path_endpoints = argv[1]
    path_xrefs = argv[2]

    main(path_endpoints, path_xrefs)
