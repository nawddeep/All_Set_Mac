"""The launch agents install_public_server.py would install. Nothing is installed here.

    /usr/bin/python3 -m unittest scripts/cloud/test_install_public_server.py
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
import install_public_server  # noqa: E402

SERVER = os.path.join(HERE, "server.sh")


class PublicLaunchAgentTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.mkdtemp(prefix="allset-launchd-test-")

    def tearDown(self):
        shutil.rmtree(self.folder, ignore_errors=True)

    def test_the_database_web_server_and_key_service_are_kept_running_and_the_backup_is_nightly(self):
        made = install_public_server.agents(SERVER, "/Users/server/allSetServer")
        self.assertEqual(sorted(made), sorted(install_public_server.LABELS))
        for label in ("com.allset.public-postgres", "com.allset.public-web", "com.allset.public-api"):
            self.assertTrue(made[label]["KeepAlive"] and made[label]["RunAtLoad"])
        self.assertEqual(made["com.allset.public-api"]["ProgramArguments"][2], "api")
        nightly = made["com.allset.public-backup"]
        self.assertEqual(nightly["StartCalendarInterval"], {"Hour": 3, "Minute": 30})
        self.assertNotIn("KeepAlive", nightly)
        for label, body in made.items():
            self.assertEqual(body["ProgramArguments"][:2], ["/bin/bash", SERVER])
            self.assertEqual(body["EnvironmentVariables"]["ALLSET_SERVER_DIR"], "/Users/server/allSetServer")
            self.assertTrue(body["StandardErrorPath"].startswith("/Users/server/allSetServer/logs/"))

    def test_every_agent_runs_a_command_the_server_script_has(self):
        with open(SERVER) as handle:
            script = handle.read()
        for body in install_public_server.agents(SERVER, "/x").values():
            self.assertIn(f"\n    {body['ProgramArguments'][2]})", script)

    def test_no_password_is_written_into_a_launch_agent(self):
        made = install_public_server.agents(SERVER, "/Users/server/allSetServer")
        text = repr(made)
        self.assertNotIn("postgres://", text)
        self.assertNotIn("DATABASE_URL", text)

    def test_print_writes_valid_property_lists_and_installs_nothing(self):
        installed = os.path.expanduser("~/Library/LaunchAgents")
        before = sorted(os.listdir(installed)) if os.path.isdir(installed) else []
        result = subprocess.run([sys.executable, os.path.join(HERE, "install_public_server.py"), "--print", self.folder,
                                 "--server", SERVER, "--root", "/Users/server/allSetServer"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        written = sorted(os.listdir(self.folder))
        self.assertEqual(written, sorted(label + ".plist" for label in install_public_server.LABELS))
        for name in written:
            path = os.path.join(self.folder, name)
            # macOS's own check where it exists; plistlib below parses it everywhere.
            if os.path.exists("/usr/bin/plutil"):
                lint = subprocess.run(["/usr/bin/plutil", "-lint", path], capture_output=True, text=True)
                self.assertEqual(lint.returncode, 0, lint.stdout)
            with open(path, "rb") as handle:
                self.assertEqual(plistlib.load(handle)["Label"] + ".plist", name)
        after = sorted(os.listdir(installed)) if os.path.isdir(installed) else []
        self.assertEqual(before, after)

    def test_installing_needs_to_be_told_which_server(self):
        result = subprocess.run([sys.executable, os.path.join(HERE, "install_public_server.py")], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
