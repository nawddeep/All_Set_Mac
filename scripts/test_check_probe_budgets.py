"""The CI probe budget check.

    /usr/bin/python3 -m unittest scripts/test_check_probe_budgets.py
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_probe_budgets as probe  # noqa: E402

BUDGETS = {"page_cpu_percent": 40, "scroll_cpu_percent": 160, "scroll_max_frame_ms": 1500, "scroll_hitches": 60,
           "gallery_part_worst_ms": 3000, "required": ["page", "scroll", "gallery part"]}
GOOD = [
    "themes               4.2% CPU ( 1.1% kernel)    60 GPU frames/s",
    "scroll gallery      48.3% CPU  frames 240  p50  8.1 ms  p95 18.2 ms  max  80.0 ms  hitches(>33ms) 3  range 9000 pt",
    "gallery part hero             median   12.0 ms  worst   40.0 ms",
]


class ProbeBudgetTests(unittest.TestCase):
    """Review O3: CI recorded performance numbers but never failed on them."""

    def test_numbers_within_budget_pass(self):
        self.assertEqual(probe.check(GOOD, BUDGETS), [])

    def test_a_heavier_page_fails(self):
        lines = GOOD + ["wallpaper           55.0% CPU ( 3.0% kernel)    60 GPU frames/s"]
        self.assertEqual(len(probe.check(lines, BUDGETS)), 1)

    def test_a_janky_scroll_fails(self):
        lines = GOOD[:1] + GOOD[2:] + [
            "scroll themes       40.0% CPU  frames 100  p50  9.0 ms  p95 90.0 ms  max 2400.0 ms  hitches(>33ms) 75  range 9000 pt"]
        self.assertEqual(len(probe.check(lines, BUDGETS)), 2)

    def test_a_probe_that_measured_nothing_fails(self):
        self.assertEqual(len(probe.check([], BUDGETS)), 3)

    def test_the_budget_file_parses_and_passes_good_numbers(self):
        import json
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "probe-budgets.json")) as handle:
            self.assertEqual(probe.check(GOOD, json.load(handle)), [])


if __name__ == "__main__":
    unittest.main()
