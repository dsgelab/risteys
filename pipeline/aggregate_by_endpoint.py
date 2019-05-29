"""
Aggregate data by endpoint on a couple of metrics, for female, male and all sex.

Usage:
    python aggregate_by_endpoint.py <data-directory>

For each endpoint we want the metrics:
- number of individuals --> COUNT
- un-adjusted prevalence --> TOTAL number of individuals
- mean age at first-event --> AGE LIST
- median number of events by individual --> MAP {indiv -> count}
- re-occurence within 6 months --> MAP {indiv -> [LIST AGEs]}
- case fatality at 5 years --> MAP {indiv -> {first event: AGE, death: AGE}}
- age distribution --> AGE LIST
- year distribution --> YEAR LIST
"""
from pathlib import Path
from sys import argv

from utils import file_exists


INPUT_LONGIT_FILE = "FINNGEN_ENDPOINTS_longitudinal.txt"
INPUT_MINIMUM_DATA_FILE = "FINNGEN_MINIMUM_DATA.txt"
OUTPUT_FILE = "aggregated_data.json"


def prechecks(longit_file, mindata_file):
    assert file_exists(longit_file)
    assert file_exists(mindata_file)
    assert not file_exists(OUTPUT_FILE)

    # Check headers, consuming them from the files.
    with open(longit_file) as f:
        headers = next(f)
        headers = headers.rstrip()
        headers = headers.split("\t")
        assert headers == ["FINNGENID", "EVENT_AGE", "EVENT_YEAR", "ENDPOINT"]


def main(data_dir):
    longit_file = data_dir / INPUT_LONGIT_FILE
    mindata_file = data_dir / INPUT_MINIMUM_DATA_FILE
    prechecks(longit_file, mindata_file)

    indivs = set()
    with open(longit_file) as f:
        for line in f:
            line = line.rstrip()
            line = line.split("\t")
            finngen_id = line[0]
            indivs.add(finngen_id)
    print(len(indivs))

if __name__ == '__main__':
    data_dir = Path(argv[1])
    main(data_dir)
