"""
Get the list of endpoints to exclude in FinRegistry.

An endpoint could be excluded in FinRegistry for a couple of reasons:
- Endpoint definition changes between the version used by FinRegistry and the version
  used by FinnGen when presented on Risteys.
- Endpoints with OMIT in {1, 2} are not run in FinRegistry pipeline.
- Endpoints having in their definition HD_ICD_10_ATC = "ANY"
- Some specifics endpoints are manually excluded (e.g. DEATH, F5_SAD)

For backward compatibility 1 or 3 reasons can be used for excluded endpoints:
- excl_diff_def
- excl_omitted
- excl_not_available
"""
import argparse
import csv
import sys
from pathlib import Path

# Make our pipeline library code discoverable by this script.
lib_path = str((Path(__file__).parent.parent))
sys.path.append(lib_path)
from risteys_pipeline.utils.log import logger


def main():
    args = parse_cli()
    
    logger.info("Loading definition files")
    old_defs, old_header = load_definitions(args.old)
    new_defs, new_header = load_definitions(args.new)

    # Data checks
    logger.info("Performing data checks")
    assert old_header == new_header

    old_omits = {defn["OMIT"] for defn in old_defs.values()}
    assert old_omits == set(["", "1", "2"]), f"{old_omits=}"

    # 1. Figure out which endpoints are directly or indirectly affected by definition changes
    logger.info("Finding directly and indirectly changed endpoints")
    directly_affected = find_change(old_defs, new_defs)
    old_tree = make_tree(old_defs)
    old_descendants = {endpoint: descendants_of(endpoint, old_tree, set()) for endpoint in old_tree.keys()}
    indirectly_affected = cascade_change(old_descendants, directly_affected)
    all_affected = directly_affected.union(indirectly_affected)

    # 2. Find endpoints that were omitted in FinRegistry
    # 3. Find endpoints that were not run in FinRegistry due to handling of HD_ICD_10_ATC
    logger.info("Getting excluded endpoints based on FinRegistry handling")
    all_omitted = set()
    all_bad_handling = set()
    for endpoint, defn in old_defs.items():
        if defn["OMIT"] != "":
            all_omitted.add(endpoint)

        if defn["HD_ICD_10_ATC"] == "ANY":
            all_bad_handling.add(endpoint)

    # 4. Some manually excluded endpoints in FinRegistry
    all_manually_excluded = set(["DEATH", "F5_SAD"])

    # Write output to stdout
    logger.info("Writing output to stdout")
    print("endpoint,reason_finregistry_excluded")

    for endpoint in all_omitted:
        print(f"{endpoint},excl_omitted")

    for endpoint in (all_affected - all_omitted):
        print(f"{endpoint},excl_diff_def")

    not_avail = all_bad_handling.union(all_manually_excluded) - all_omitted - all_affected
    for endpoint in not_avail:
        print(f"{endpoint},excl_not_available")


def parse_cli():
    parser = argparse.ArgumentParser()
    parser.add_argument("--old", help="Old endpoint definition file used by FinRegistry", type=Path, required=True)
    parser.add_argument("--new", help="New endpoint definition file used by FinnGen", type=Path, required=True)
    
    args = parser.parse_args()

    logger.debug(f"path to old definition file used by FinRegistry: {args.old}")
    logger.debug(f"path to new definition file used by FinnGen: {args.new}")
    
    return args
    

def load_definitions(file_path):
    defs = {}
    
    with open(file_path) as fd:
        reader = csv.DictReader(fd)
        header = set(reader.fieldnames)

        for row in reader:
            out_row = {}
            endpoint_name = row["NAME"]

            for col, value in row.items():
                out_row[col] = value

            defs[endpoint_name] = out_row

    return defs, header


def find_change(old_defs, new_defs):
    """Return the list of endpoints directly affected by changes between old and new definitions"""
    added = set(new_defs.keys()) - set(old_defs.keys())
    logger.debug(f"N endpoints added: {len(added)}\n{added}\n")

    removed = set(old_defs.keys()) - set(new_defs.keys())
    logger.debug(f"N endpoints removed: {len(removed)}\n{removed}\n")

    all_columns = set(list(old_defs.values())[0])
    # Change in the values of the following columns do not affect the selection
    # of cases or controls, so we disard them.
    discard_columns = set([
        "TAGS",
        "LEVEL",
        "OMIT",
        "CORE_ENDPOINTS",
        "REASON_FOR_NONCORE",
        "LONGNAME",
        "Special",
        "version",
        "Latin",
        "Modification_date",
        "Modified_by",
        "Modification_reason",
        "CONTROLS_Modification_date",
        "CONTROLS_Modified_by",
        "CONTROLS_Modification_reason"
    ])
    lookup_columns = all_columns - discard_columns

    in_common = set(old_defs.keys()).intersection(set(new_defs.keys()))
    changed = set()
    for endpoint in in_common:
        for col in lookup_columns:
            old_value = old_defs[endpoint][col]
            new_value = new_defs[endpoint][col]

            if old_value != new_value:
                logger.debug(f"change in {endpoint}::{col} : {old_value} --> {new_value}")
                changed.add(endpoint)

    logger.debug(f"N endpoints changed: {len(changed)}\n{changed}\n")

    endpoints = added.union(removed).union(changed)
    logger.debug(f"N total directly affected endpoints: {len(endpoints)}")

    return endpoints


def make_tree(definitions):
    tree = {}

    for endpoint, data in definitions.items():
        if data["INCLUDE"] == '':
            children = []
        else:
            children = data["INCLUDE"].split("|")

            # Some endpoints are prefix with 'K.' to indicate to look them-up in the cause of
            # death registry. We remove this prefix to return a list of actual endpoint names.
            children = map(lambda ee: ee[2:] if ee.startswith('K.') else ee, children)

        tree[endpoint] = set(children)
    
    return tree


def descendants_of(endpoint, tree, acc):
    direct_desc = tree[endpoint]
    acc.update(direct_desc)
    for desc in direct_desc:
        descendants_of(desc, tree, acc)
    return acc


def cascade_change(descendants, directly_affected):
    """Return the list of endpoints from the input where at least 1 of its descendant is in the directly_affected list"""
    affected = []

    for endpoint, endpoint_descendants in descendants.items():
        if len(directly_affected.intersection(endpoint_descendants)) > 0:
            affected.append(endpoint)
    logger.debug(f"N indirectly affected endpoints: {len(affected)}\n{affected}\n")

    return affected


if __name__ == '__main__':
    main()