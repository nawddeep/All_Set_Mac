"""The launch agents install_services.py would install. Nothing is installed here.

    /usr/bin/python3 -m unittest scripts/cloud/test_install_services.py
"""
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import install_services  # noqa: E402


class LaunchAgentTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.mkdtemp(prefix="allset-launchd-test-")

    def tearDown(self):
        shutil.rmtree(self.folder, ignore_errors=True)

    def test_the_services_are_kept_running_and_the_backup_is_nightly_with_a_drill(self):
        made = install_services.agents("/Users/server", backups="/Volumes/Backup/AllSet")
        self.assertEqual(sorted(made), sorted(install_services.LABELS))
        for label in install_services.LABELS[:2]:
            self.assertTrue(made[label]["KeepAlive"] and made[label]["RunAtLoad"])
            self.assertEqual(made[label]["ProgramArguments"][0], "/usr/bin/python3")
            self.assertTrue(os.path.isfile(made[label]["ProgramArguments"][1]), made[label]["ProgramArguments"][1])
            self.assertTrue(made[label]["StandardErrorPath"].startswith("/Users/server/Library/Logs/AllSet/"))
        nightly = made["com.allset.backup"]
        self.assertEqual(nightly["ProgramArguments"][2:], ["backup", "/Volumes/Backup/AllSet", "--drill"])
        self.assertEqual(nightly["StartCalendarInterval"], {"Hour": 3, "Minute": 30})
        self.assertNotIn("KeepAlive", nightly)

    def test_no_backup_folder_means_no_backup_job(self):
        self.assertNotIn("com.allset.backup", install_services.agents("/Users/server"))

    def test_quarantined_wallpapers_are_served_only_when_asked(self):
        plain = install_services.agents("/Users/server")["com.allset.catalog-service"]["ProgramArguments"]
        asked = install_services.agents("/Users/server", include_quarantined=True)["com.allset.catalog-service"]["ProgramArguments"]
        self.assertNotIn("--include-quarantined", plain)
        self.assertIn("--include-quarantined", asked)

    def test_print_writes_valid_property_lists_and_installs_nothing(self):
        installed = os.path.expanduser("~/Library/LaunchAgents")
        before = sorted(os.listdir(installed)) if os.path.isdir(installed) else []
        result = subprocess.run([sys.executable, os.path.join(HERE, "install_services.py"), "--print", self.folder,
                                 "--backups", "/Volumes/Backup/AllSet"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        written = sorted(os.listdir(self.folder))
        self.assertEqual(written, sorted(label + ".plist" for label in install_services.LABELS))
        for name in written:
            path = os.path.join(self.folder, name)
            lint = subprocess.run(["/usr/bin/plutil", "-lint", path], capture_output=True, text=True)
            self.assertEqual(lint.returncode, 0, lint.stdout)
            with open(path, "rb") as handle:
                self.assertEqual(plistlib.load(handle)["Label"] + ".plist", name)
        after = sorted(os.listdir(installed)) if os.path.isdir(installed) else []
        self.assertEqual(before, after)


if __name__ == "__main__":
    unittest.main()
