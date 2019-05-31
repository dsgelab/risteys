"""
Aggregate data by endpoint on a couple of metrics, for female, male and all sex.

Usage:
    python aggregate_by_endpoint.py <data-file-longitudinal> <data-file-indivs-sex> <output-dir>

For each endpoint we want the metrics:
- number of individuals --> COUNT
- un-adjusted prevalence --> TOTAL number of individuals
- mean age at first-event --> AGE LIST
- median number of events by individual --> MAP {indiv -> count}
- re-occurence within 6 months --> MAP {indiv -> [LIST AGEs]}
- case fatality at 5 years --> MAP {indiv -> {first event: AGE, death: AGE}}
- age distribution --> AGE LIST
- year distribution --> YEAR LIST

Output:
- JSON file with hierarchy: {endpoint -> {indiv -> [(event age, event year) , ...] (sorted) }}
- JSON file with the total number of individual by sex
"""
from collections import defaultdict
from pathlib import Path
from sys import argv

import ujson

from log import logger
from utils import file_exists


OUTPUT_AGG_FILENAME = "aggregated_data.json"
OUTPUT_COUNT_FILENAME = "count_by_sex.json"
COL_FID = 0
COL_EVENT_AGE = 1
COL_EVENT_YEAR = 2
COL_ENDPOINT = 3


def prechecks(longit_file, sex_file):
    assert file_exists(longit_file), f"{longit_file} doesn't exist"
    assert file_exists(sex_file), f"{sex_file} doesn't exist"
    assert not file_exists(OUTPUT_AGG_FILE), f"{OUTPUT_AGG_FILE} already exists, not overwritting it"
    assert not file_exists(OUTPUT_COUNT_FILE), f"{OUTPUT_COUNT_FILE} already exists, not overwritting it"

    # Check event file headers
    with open(longit_file) as f:
        headers = next(f)
        headers = headers.rstrip()
        headers = headers.split("\t")
        assert headers[COL_FID] == "FINNGENID"
        assert headers[COL_EVENT_AGE] == "EVENT_AGE"
        assert headers[COL_EVENT_YEAR] == "EVENT_YEAR"
        assert headers[COL_ENDPOINT] == "ENDPOINT"

    # Check sex for all individuals
    with open(sex_file) as f:
        sexs = ujson.load(f)
    extra = set(sexs.values()) - set(["female", "male"])
    assert len(extra) == 0, f"Sex other than 'female' or 'male' in {sex_file}: {extra}"


def main(longit_file, sex_file):
    prechecks(longit_file, sex_file)

    logger.info("Parsing events")
    endpoints, indivs = parse_events(longit_file)
    logger.info("Writing JSON file for aggregated events")
    with open(OUTPUT_AGG_FILE, "x") as f:
        ujson.dump(endpoints, f)

    logger.info("Counting individuals")
    counts = count_indivs(indivs)
    logger.info("Writing indivudal counts")
    with open(OUTPUT_COUNT_FILE, "x") as f:
        ujson.dump(counts, f)

    logger.info("Done.")


def parse_events(longit_file):
    endpoints = defaultdict(lambda: defaultdict(list))
    indivs = set()

    with open(longit_file) as f:
        next(f)  # skip header line
        for ii, line in enumerate(f):
            if ii % 100_000 == 0:
                logger.debug(f"at line {ii}")
            # Parse line
            line = line.rstrip()
            line = line.split("\t")
            finngen_id = line[COL_FID]
            event_age = line[COL_EVENT_AGE]
            event_age = float(event_age)
            event_year = line[COL_EVENT_YEAR]
            event_year = int(event_year)
            endpoint = line[COL_ENDPOINT]

            # Add data event
            endpoints[endpoint][finngen_id].append((event_age, event_year))
            # Add individual ID for counting
            indivs.add(finngen_id)

    return endpoints, indivs


def count_indivs(indivs):
    """Count individuals by sex"""
    with open(sex_file) as f:
        indivs_sex = ujson.load(f)

    count_all = len(indivs)
    count_female = len(list(filter(lambda ind: indivs_sex[ind] == "female", indivs)))
    count_male = len(list(filter(lambda ind: indivs_sex[ind] == "male", indivs)))
    counts = {
        "all": count_all,
        "female": count_female,
        "male": count_male,
    }

    return counts
    

if __name__ == '__main__':
    longit_file = Path(argv[1])
    sex_file = Path(argv[2])
    output_dir = Path(argv[3])

    # Set output file paths globally
    OUTPUT_AGG_FILE = output_dir / OUTPUT_AGG_FILENAME
    OUTPUT_COUNT_FILE = output_dir / OUTPUT_COUNT_FILENAME

    main(longit_file, sex_file)
