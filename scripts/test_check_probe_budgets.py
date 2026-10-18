"""The CI probe budget check.

    /usr/bin/python3 -m unittest scripts/test_check_probe_budgets.py
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_probe_budgets as probe  # noqa: E402

BUDGETS = {"page_cpu_percent": 40, "scroll_cpu_percent": 160, "scroll_max_frame_ms": 1500, "scroll_hitches": 60,
           "gallery_part_worst_ms": 3000, "idle_widget_cpu_percent": 1, "required": ["page", "scroll", "gallery part", "idle"]}
GOOD = [
    "themes               1.2% CPU ( 1.1% kernel)    60 GPU frames/s",
    # Exactly as PageCPUProbe.runScroll prints it: the name has a space.
    "scroll gallery 1st  48.3% CPU  frames 240  p50  8.1 ms  p95 18.2 ms  max  80.0 ms  hitches(>33ms) 3  range 9000 pt",
    "gallery part hero             median   12.0 ms  worst   40.0 ms",
    "clock visible: 0.378% CPU",
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
            "scroll themes 2nd   40.0% CPU  frames 100  p50  9.0 ms  p95 90.0 ms  max 2400.0 ms  hitches(>33ms) 75  range 9000 pt"]
        self.assertEqual(len(probe.check(lines, BUDGETS)), 2)

    def test_a_probe_that_measured_nothing_fails(self):
        self.assertEqual(len(probe.check([], BUDGETS)), 4)  # page, scroll, gallery part, idle

    def test_scroll_names_with_spaces_are_read(self):
        """The first CI run failed with "no scroll measurements": every line the
        probe printed was named like "themes 1st", which the old pattern missed."""
        lines = ["scroll themes 1st    52.0% CPU  frames 300  p50  8.0 ms  p95 19.0 ms  max  85.0 ms  hitches(>33ms) 4  range 9000 pt"]
        measured = []
        problems = probe.check(lines, BUDGETS, measured)
        self.assertNotIn("no scroll measurements in the probe output", problems)
        self.assertEqual(measured, ["scroll themes 1st: 52.0% CPU, longest frame 85.0 ms, 4 hitches"])

    def test_a_null_ceiling_is_not_checked(self):
        """A GPU-less CI runner has a hitch on nearly every frame."""
        lines = GOOD[:1] + GOOD[2:] + [
            "scroll themes 2nd   40.0% CPU  frames 75  p50 80.0 ms  p95 90.0 ms  max 120.0 ms  hitches(>33ms) 74  range 9000 pt"]
        self.assertEqual(probe.check(lines, {**BUDGETS, "scroll_hitches": None}), [])
        self.assertEqual(len(probe.check(lines, BUDGETS)), 1)

    def test_the_budget_file_parses_and_passes_good_numbers(self):
        import json
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "probe-budgets.json")) as handle:
            self.assertEqual(probe.check(GOOD, json.load(handle)), [])

    def test_a_page_with_its_own_ceiling_uses_it_and_others_keep_the_general_one(self):
        budgets = dict(BUDGETS, page_cpu_percent=2.75, page_cpu_percent_by_page={"themes": 32})
        # Themes at 25% passes on its own ceiling; the same reading on another page does not.
        self.assertEqual(probe.check(["themes   25.4% CPU ( 0.8% kernel)    0 GPU frames/s"] + GOOD[1:], budgets), [])
        problems = probe.check(["wallpaper   25.4% CPU ( 0.8% kernel)    0 GPU frames/s"] + GOOD[1:], budgets)
        self.assertEqual(len(problems), 1)
        self.assertIn("2.75%", problems[0])
        # Past its own ceiling, Themes fails too.
        self.assertEqual(len(probe.check(["themes   40.0% CPU ( 0.8% kernel)    0 GPU frames/s"] + GOOD[1:], budgets)), 1)

    def test_an_idle_clock_that_costs_too_much_fails(self):
        problems = probe.check(GOOD + ["clock covered: 3.5% CPU"], BUDGETS)
        self.assertEqual(len(problems), 1)
        self.assertIn("idle seconds clock covered", problems[0])

if __name__ == "__main__":
    unittest.main()
