"""
Map of Finngen ID -> sex.

Usage:
    python get_indivs_sex.py <data-dir>

Output: a JSON file with a mapping of Finngen ID -> "male" or "female"

<data-dir> must contains a file named FINNGEN_MINIMUM_DATA.txt
This file should have the following header:
    FINNGENID	BL_YEAR	BL_AGE	SEX	HEIGHT	HEIGHT_AGE	WEIGHT	WEIGHT_AGE	SMOKE2	SMOKE3	SMOKE5	regionofbirth	regionofbirthname	movedabroad
"""
from json import dump
from pathlib import Path
from sys import argv

from utils import file_exists


INPUT_FILE = "FINNGEN_MINIMUM_DATA.txt"
OUTPUT_FILE = "indivs_sex.json"
COL_ID = 0
COL_SEX = 3


def prechecks(data_file):
    assert file_exists(data_file), f"{data_file} doesn't exist"
    assert not file_exists(OUTPUT_FILE), f"{OUTPUT_FILE} already exists, not overwritting it"

    # Check headers are in correct positions.
    with open(data_file) as f:
        headers = next(f)
        headers = headers.rstrip()
        headers = headers.split("\t")
        assert headers[COL_ID] == "FINNGENID" and headers[COL_SEX] == "SEX"


def main(data_dir):
    data_file = data_dir / INPUT_FILE
    prechecks(data_file)

    ids_sex = map_ids_sex(data_file)

    with open(OUTPUT_FILE, "x") as f:
        dump(ids_sex, f)


def map_ids_sex(data_file):
    """Build the mapping of Finngen ID -> sex."""
    res = {}
    with open(data_file) as f:
        next(f)  # skip header line
        for line in f:
            line = line.split("\t")
            finngenid = line[COL_ID]
            sex = line[COL_SEX]
            res[finngenid] = sex
    return res

if __name__ == '__main__':
    data_dir = Path(argv[1])
    main(data_dir)
