"""
Convert Aki endpoint CSV file.
This will expand the regexes for the HD ICD-10 and COD ICD-10 columns.
"""

import csv
import logging
from sys import argv

import sre_yield


def expand(regex):
    if regex == "$!$":
        return ""

    regex = regex.replace(".", "[0-9]")
    try:
        values = list(sre_yield.AllStrings(regex))
    except sre_yield.ParseError:
        logging.warning(f"could not parse: {regex}")
        values = []
    except Exception as e:
        logging.warning(f"could not parse: {regex}")
        logging.warning(e)
        values = []

    values = " ".join(values)
    return values


with open(argv[1], newline='') as fread, open(argv[2], 'w', newline='') as fwrite:
    reader = csv.reader(fread)
    header = next(reader)

    writer = csv.writer(fwrite)
    writer.writerow(header)
    
    for (line_number, row) in enumerate(reader):
        row[11] = expand(row[11])  # HD ICD 10
        row[12] = expand(row[12])  # HD ICD 9
        row[13] = expand(row[13])  # HD ICD 8
        row[14] = expand(row[14])  # HD ICD 10 excl
        row[15] = expand(row[15])  # HD ICD 9 excl
        row[16] = expand(row[16])  # HD ICD 8 excl

        row[18] = expand(row[18])  # COD ICD 10
        row[19] = expand(row[19])  # COD ICD 9
        row[20] = expand(row[20])  # COD ICD 8
        row[21] = expand(row[21])  # COD ICD 10 excl
        row[22] = expand(row[22])  # COD ICD 9 excl
        row[23] = expand(row[23])  # COD ICD 8 excl

        row[24] = expand(row[24])  # OPER NOM
        row[25] = expand(row[25])  # OPER HL
        row[26] = expand(row[26])  # OPER HP1
        row[27] = expand(row[27])  # OPER HP2

        row[28] = expand(row[28])  # KELA REIM
        row[29] = expand(row[29])  # KELA REIM ICD
        row[31] = expand(row[31])  # KELA ATC

        row[34] = expand(row[34])  # KELA ATC

        writer.writerow(row)
