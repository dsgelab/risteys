"""Select pairs of endpoints to do survival analysis on.

Usage
-----
See 'python surv_select_endpoint_pairs.py --help'

Input files
-----------
- endpoint-definitions
  Each row is an endpoint definition.
  Format: CSV
  Source: FinnGen data
- priority-endpoints
  Each row is an endpoint name that is part of the FinnGen endpoint
  priority list.
  Format: CSV
  Source: FinnGen
- correlations
  Each row is an endpoint pair with a case-ratio correlation value.
  Format: CSV
  Source: FinnGen correlation project https://github.com/FINNGEN/endpcorr

Description
-----------
Survival analysis is done on a exposure-outcome endpoint pair.

If a user wants to know the strongest associations for endpoint E,
then we have to do a Cox regression for each endpoint pair that
contains E. That is:
- (*, E): association from any endpoint that then leads to endpoint E
- (E, *): association from E that then leads to any endpoint.

This is a lot of endpoint combinations, so here we select only a
subset of these combinations.
"""
import argparse
import csv
from pathlib import Path


def main():
    args = cli_parser()

    endpoints = load_endpoints(args.endpoint_definitions)
    endpoints = filter_core(endpoints)
    endpoints = filter_omit(endpoints)
    prios = load_priority_endpoints(args.priority_endpoints)
    pairs = gen_pairs(prios, endpoints)
    pairs = filter_correlations(args.correlations, pairs)

    write_output(args.output, pairs)


def cli_parser():
    parser = argparse.ArgumentParser()

    # CSV file converted from FinnGen endpoint definition Excel file
    parser.add_argument(
        '-e', '--endpoint-definitions',
        help='path to the endpoint definitions (CSV)',
        type=Path,
        required=True
    )

    # CSV file from FinnGen with a list of ~150 priority endpoints
    parser.add_argument(
        '-p', '--priority-endpoints',
        help='path to the list of priority endpoints (CSV)',
        type=Path,
        required=True
    )

    # CSV file from FinnGen correlation script
    parser.add_argument(
        '-c', '--correlations',
        help='path to the endpoint correlations (CSV)',
        type=Path,
        required=True
    )

    parser.add_argument(
        '-o', '--output',
        help='path to output file containing endpoint pairs (CSV)',
        type=Path,
        required=True
    )

    args = parser.parse_args()
    return args


def load_endpoints(filepath):
    """Load the endpoint definitions and return a list of enpoint infos"""
    with open(filepath) as ff:
        reader = csv.DictReader(ff)

        # Keep only necessary columns
        endpoints = []
        for row in reader:
            endpoints.append({
                'NAME': row['NAME'],
                'OMIT': row['OMIT'],
                'CORE_ENDPOINTS': row['CORE_ENDPOINTS']
            })

    return endpoints


def load_priority_endpoints(filepath):
    """Load the list of priority endpoints"""
    expected_header = ["Code"]
    col_code = 0
    with open(filepath) as ff:
        reader = csv.reader(ff)
        assert next(reader) == expected_header  # check and discard header
        prios = {row[col_code] for row in reader}
    return prios


def filter_core(endpoints):
    """Keep only core endpoints"""
    return list(filter(lambda endp: endp["CORE_ENDPOINTS"] == "yes", endpoints))


def filter_omit(endpoints):
    """Keep only non-OMITed endpoints"""
    return list(filter(lambda endp: endp["OMIT"] == "", endpoints))


def gen_pairs(prios, endpoints):
    """Generate exposure-outcome endpoint pairs.

    This also acts as a filter by only generating endpoint pairs
    linked to a priority endpoints.
    """
    pairs = []
    for prio in prios:
        for endp in endpoints:
            name = endp['NAME']
            pairs.append((prio, name))
            pairs.append((name, prio))
    return pairs


def filter_correlations(filepath, pairs):
    """Filter endpoint pairs based on their case-control correlation"""
    res = []
    max_case_ratio = 0.9
    pairs = set(pairs)
    with open(filepath) as ff:
        reader = csv.DictReader(ff)
        for row in reader:
            corr_pair = (row['endpoint_a'], row['endpoint_b'])
            if corr_pair in pairs and float(row['case_ratio']) < max_case_ratio:
                res.append(corr_pair)
    return res


def write_output(filepath, pairs):
    """Write the exposure-outcome endpoint pairs to a CSV file"""
    header = ['exposure_endpoint', 'outcome_endpoint']
    with open(filepath, 'w') as ff:
        writer = csv.writer(ff)
        writer.writerow(header)
        writer.writerows(pairs)


if __name__ == '__main__':
    main()
