import argparse
import csv
import json
import shutil
from pathlib import Path
from sys import stderr


N_MIN_COHORT_CASES = 50
N_MIN_COHORT_CONTROLS = 50
N_MIN_GREEN = 5

MIN_NLOG10P = 6.0


def main():
    args = cli_init()

    print("Processing starts...", file=stderr)

    for json_path in args.input_dir.glob('*.json'):
        endpoint = json_path.stem

        print(f"Checking data for {endpoint=}", file=stderr)

        can_keep_cohort, n_matched_cases, n_matched_controls = check_cohort(json_path)
        if can_keep_cohort:
            csv_path = json_path.with_suffix(".csv")

            green_records = filter_and_greenize_csv(csv_path)

            if green_records:
                data = {
                    "endpoint_name": endpoint,
                    "n_matched_cases": n_matched_cases,
                    "n_matched_controls": n_matched_controls,
                    "codes": green_records
                }

                print(json.dumps(data))

            else:
                print(f"{endpoint=} :: Did not find any records.", file=stderr)

        else:
            print(f"{endpoint=} :: Cohort matched cases/controls don't meet the minimum N requirement.", file=stderr)

    print("Done.", file=stderr)


def cli_init():
    arg_parser = argparse.ArgumentParser()

    arg_parser.add_argument("--input-dir", type=Path, required=True)

    args = arg_parser.parse_args()
    return args


def check_cohort(path):
    with open(path) as fd:
        content = json.load(fd)

    n_matched_cases = int(content["n_cases"] * content["per_cases_after_match"])
    n_matched_controls = int(content["n_controls"] * content["per_controls_after_match"])

    can_keep = n_matched_cases >= N_MIN_COHORT_CASES and n_matched_controls >= N_MIN_COHORT_CONTROLS

    return can_keep, n_matched_cases, n_matched_controls


def filter_and_greenize_csv(path):
    filtered_and_green_records = []

    with open(path) as fd:
        reader = csv.DictReader(fd)

        for rr in reader:
            # Keep only records with nlog10p >= MIN_NLOG10P 
            if float(rr["nlog10p"]) < MIN_NLOG10P:
                continue

            n_matched_cases = int(rr["n_cases_yes"])
            if n_matched_cases < N_MIN_GREEN:
                n_matched_cases = None

            n_matched_controls = int(rr["n_controls_yes"])
            if n_matched_controls < N_MIN_GREEN:
                n_matched_controls = None

            # The JSON spec doesn't allow Infinity as a number.
            # Some JSON parsers allow it (like python), but other (like Elixir Jason)
            # follow the spec and don't allow it.
            if rr["OR"] == "Inf":
                odds_ratio = "Infinity"
            else:
                odds_ratio = float(rr["OR"])

            filtered_and_green_records.append({
                "code1": rr["FG_CODE1"],
                "code2": rr["FG_CODE2"],
                "code3": rr["FG_CODE3"],
                "description": rr["name_en"],
                "vocabulary": rr["vocabulary_id"],
                "odds_ratio": odds_ratio,
                "nlog10p": float(rr["nlog10p"]),
                "n_matched_cases": n_matched_cases,
                "n_matched_controls": n_matched_controls
            })

    return filtered_and_green_records


if __name__ == '__main__':
    main()
