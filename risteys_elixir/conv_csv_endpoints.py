"""
Convert Aki endpoint CSV file.
This will expand the regexes for the HD ICD-10 and COD ICD-10 columns.
"""

import csv
import logging
from sys import argv

import sre_yield


with open(argv[1], newline='') as fread, open(argv[2], 'w', newline='') as fwrite:
    reader = csv.reader(fread)
    header = next(reader)

    writer = csv.writer(fwrite)
    writer.writerow(header)
    
    for (line_number, row) in enumerate(reader):
        hd_codes = row[11]

        # Not parsing regex with "." in it since it will expand to unwanted characters (like NULL byte)
        # and cause problem importing it into the DB afterwards.
        if not "." in hd_codes:
            try:
                hd_codes = list(sre_yield.AllStrings(hd_codes))
            except sre_yield.ParseError:
                logging.warning(f"could not parse: {hd_codes}")
            except Exception as e:
                logging.warning(e)
            hd_codes = " ".join(hd_codes)
            row[11] = hd_codes

        cod_codes = row[18]
        if not "." in cod_codes:
            try:
                cod_codes = list(sre_yield.AllStrings(cod_codes))
            except sre_yield.ParseError:
                logging.warning(f"Could not parse: {hd_codes}")
            except Exception as e:
                logging.warning(e)
            cod_codes = " ".join(cod_codes)
            row[18] = cod_codes

        writer.writerow(row)

