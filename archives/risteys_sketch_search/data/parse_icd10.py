"""
Parses the icd10cm_order_2019.txt to a JSON representation.
"""

import json
from sys import argv


def main(filepath):
    res = []
    with open(filepath) as f:
        lines = f.readlines()
    for line in lines:
        # We use the fact that the file is column aligned to get the columns we want.
        # This is not regular CSV parsing, as it doesn't rely on comma or tab-separated fields.
        icd = line[6:13].strip()
        desc = line[77:].strip()
        if len(icd) == 3:
            res.append((icd, desc))
    print(json.dumps(res))


if __name__ == '__main__':
    r = main(argv[1])
