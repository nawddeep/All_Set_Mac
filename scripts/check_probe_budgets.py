"""Fails when the CI probe's numbers go past their budgets, or when a kind of
measurement is missing (a probe that printed nothing must not pass).

    /usr/bin/python3 scripts/check_probe_budgets.py probe.txt [scripts/probe-budgets.json]

Reads the lines the app's DEBUG `-probe pages | scroll | galleryparts` print.
"""
import json
import os
import re
import sys

PAGE = re.compile(r"^(?P<name>\S.*?)\s+(?P<cpu>[\d.]+)% CPU \(\s*[\d.]+% kernel\)")
SCROLL = re.compile(r"^scroll (?P<name>\S+)\s+(?P<cpu>[\d.]+)% CPU\s+frames\s+\d+\s+p50\s+[\d.]+ ms\s+p95\s+[\d.]+ ms\s+"
                    r"max\s+(?P<max>[\d.]+) ms\s+hitches\(>33ms\) (?P<hitches>\d+)")
PART = re.compile(r"^gallery part (?P<name>\S.*?)\s+median\s+[\d.]+ ms\s+worst\s+(?P<worst>[\d.]+) ms")


def check(lines, budgets):
    """Problems (empty when everything is within budget)."""
    problems, seen = [], set()
    for line in lines:
        line = line.rstrip()
        if match := SCROLL.match(line):
            seen.add("scroll")
            name = match["name"]
            if float(match["cpu"]) > budgets["scroll_cpu_percent"]:
                problems.append(f"scroll {name}: {match['cpu']}% CPU > {budgets['scroll_cpu_percent']}%")
            if float(match["max"]) > budgets["scroll_max_frame_ms"]:
                problems.append(f"scroll {name}: longest frame {match['max']} ms > {budgets['scroll_max_frame_ms']} ms")
            if int(match["hitches"]) > budgets["scroll_hitches"]:
                problems.append(f"scroll {name}: {match['hitches']} hitches > {budgets['scroll_hitches']}")
        elif match := PART.match(line):
            seen.add("gallery part")
            if float(match["worst"]) > budgets["gallery_part_worst_ms"]:
                problems.append(f"gallery part {match['name']}: worst {match['worst']} ms > {budgets['gallery_part_worst_ms']} ms")
        elif match := PAGE.match(line):
            seen.add("page")
            if float(match["cpu"]) > budgets["page_cpu_percent"]:
                problems.append(f"page {match['name']}: {match['cpu']}% CPU idle > {budgets['page_cpu_percent']}%")
    for kind in budgets.get("required", []):
        if kind not in seen:
            problems.append(f"no {kind} measurements in the probe output")
    return problems


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    budget_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "probe-budgets.json")
    with open(budget_path) as handle:
        budgets = json.load(handle)
    with open(sys.argv[1]) as handle:
        problems = check(handle.readlines(), budgets)
    for problem in problems:
        print(f"::error::{problem}")
    if problems:
        sys.exit(1)
    print("probe within budgets")


if __name__ == "__main__":
    main()
