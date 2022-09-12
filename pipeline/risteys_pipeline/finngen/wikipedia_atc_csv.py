"""
Convert Wikipedia ATC info to a CSV.

USAGE
-----
python3 wikipedia_atc_csv.py Wikipedia-….xml output.csv

NOTES
-----
The input XML file can be created this way:
1. Go to https://en.wikipedia.org/wiki/Special:Export
2. Enter 'ATC_codes' then click 'Add'
3. Remove the lines not starting with 'ATC_code' from text area
4. Click 'Export'
"""

import xml.etree.ElementTree as ET
from csv import writer as csv_writer
from sys import argv

import mwparserfromhell


MW_NAMESPACE = "{http://www.mediawiki.org/xml/export-0.10/}"
MW_PAGE = MW_NAMESPACE + "page"
MW_TITLE = MW_NAMESPACE + "title"
MW_TEXT = MW_NAMESPACE + "text"


def main(xml_path):
    mapping = {}
    tree = ET.parse(xml_path)
    root = tree.getroot()

    # XML parsing
    for page in root.iter(MW_PAGE):
        title = page.find(MW_TITLE).text.replace("ATC code ", "")
        text = list(page.iter(MW_TEXT))[0].text

        mapping[title] = parse_title(text)
        mapping.update(dict(parse_level4s(title, text)))
        mapping.update(dict(parse_level5s(title, text)))
        mapping.update(dict(parse_level7s(title, text)))

    # CSV output
    with open(argv[2], "x") as f:
        writer = csv_writer(f)
        writer.writerow(["code", "desc"])
        for code, desc in mapping.items():
            writer.writerow([code, desc])


def parse_title(page_text):
    wtitle = page_text.splitlines()[0].lstrip("{").rstrip("}").split("|")
    if wtitle[0] == "ATC codes lead":
        title_pos = 3
    elif wtitle[0] == "short description":
        title_pos = 1
    else:
        raise
    return wtitle[title_pos]


def parse_level4s(level3, page_text):
    level4s = page_text.splitlines()
    level4s = filter(
        lambda l: (
            l.startswith("==")
            and not l.startswith("===")
            and level3 in l),
        level4s)
    level4s = map(lambda l: mwparserfromhell.parse(l).strip_code(), level4s)
    level4s = map(lambda l: l.split(maxsplit=1), level4s)
    return list(level4s)


def parse_level5s(level3, page_text):
    level5s = page_text.splitlines()
    level5s = filter(
        lambda l: l.startswith("===") and level3 in l,
        level5s
    )
    level5s = map(lambda l: mwparserfromhell.parse(l).strip_code(), level5s)
    level5s = map(lambda l: l.split(maxsplit=1), level5s)
    return list(level5s)


def parse_level7s(level3, page_text):
    level7s = page_text.splitlines()
    level7s = filter(lambda l: l.startswith(":" + level3), level7s)
    level7s = map(lambda l: mwparserfromhell.parse(l).strip_code(), level7s)
    level7s = map(lambda l: l.split(maxsplit=1), level7s)
    return list(level7s)


if __name__ == '__main__':
    main(argv[1])
