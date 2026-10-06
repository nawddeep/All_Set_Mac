"""Backups and the restore drill, against a throwaway Postgres and folders.

    /usr/bin/python3 -m unittest scripts/cloud/test_backup.py
"""
import datetime
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import backup  # noqa: E402
import pgtest  # noqa: E402


@unittest.skipUnless(pgtest.AVAILABLE, "needs a local Postgres")
class BackupTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pg = pgtest.Postgres()
        backup.DATABASE_URL = cls.pg.url
        backup.PSQL = pgtest.PSQL
        backup.PG_DUMP = f"{pgtest.BIN}/pg_dump"

    @classmethod
    def tearDownClass(cls):
        cls.pg.stop()

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="allset-backup-test-")
        self.storage = os.path.join(self.root, "storage")
        self.destination = os.path.join(self.root, "backups")
        backup.STORAGE = self.storage
        self.pg.sql("delete from wallpapers")
        for item_id in ("aaaa", "bbbb"):
            self.pg.sql(f"insert into wallpapers (id, title, kind, category, playback_key) values "
                        f"('{item_id}', 't', 'video', 'abstract', 'live/{item_id}.mp4')")
            self.file(f"live/{item_id}.mp4", f"video of {item_id}")
        self.file("thumbnails/aaaa.jpg", "thumb")
        self.file(".retired/cccc/1/live/cccc.mp4", "retired")
        self.file(".trash/dddd/live/dddd.mp4", "mid-delete")
        self.clock = datetime.datetime(2026, 10, 6, 1, 0, 0, tzinfo=datetime.timezone.utc)

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def file(self, relative, content):
        path = os.path.join(self.storage, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as handle:
            handle.write(content)
        return path

    def make(self, **kwargs):
        """A backup an hour after the last one."""
        self.clock += datetime.timedelta(hours=1)
        kwargs.setdefault("keep", 0)
        return backup.backup(self.destination, now=self.clock, **kwargs)

    def test_a_backup_holds_the_database_the_files_and_their_checksums(self):
        made = self.make()
        manifest = backup.read_manifest(made)
        self.assertEqual(manifest["rows"], 2)
        self.assertEqual(sorted(manifest["files"]), [".retired/cccc/1/live/cccc.mp4", "live/aaaa.mp4", "live/bbbb.mp4",
                                                     "thumbnails/aaaa.jpg"])
        self.assertEqual(manifest["files"]["live/aaaa.mp4"]["sha256"], backup.sha256(os.path.join(self.storage, "live/aaaa.mp4")))
        with open(os.path.join(made, "allset.sql")) as handle:
            self.assertIn("wallpapers", handle.read())
        # The live server is as it was.
        self.assertTrue(os.path.exists(os.path.join(self.storage, ".trash/dddd/live/dddd.mp4")))
        self.assertEqual(self.pg.sql("select count(*) from wallpapers"), "2")

    def test_the_drill_restores_and_verifies_a_good_backup_and_cleans_up(self):
        problems, summary = backup.drill(self.make())
        self.assertEqual(problems, [])
        self.assertEqual(summary, "2 wallpapers, 4 files")
        self.assertEqual(self.pg.sql("select count(*) from pg_database where datname like 'allset_drill_%'"), "0")

    def test_the_drill_catches_a_damaged_backup(self):
        made = self.make()
        # A fresh file, not a rewrite in place: backups share unchanged files as hard links.
        damaged = os.path.join(made, "files/live/aaaa.mp4")
        os.remove(damaged)
        with open(damaged, "w") as handle:
            handle.write("bit rot")
        os.remove(os.path.join(made, "files/thumbnails/aaaa.jpg"))
        problems, _ = backup.drill(made)
        self.assertIn("file differs from its checksum: live/aaaa.mp4", problems)
        self.assertIn("missing file: thumbnails/aaaa.jpg", problems)
        self.assertEqual(self.pg.sql("select count(*) from pg_database where datname like 'allset_drill_%'"), "0")

    def test_the_drill_catches_rows_and_files_that_disagree(self):
        self.pg.sql("insert into wallpapers (id, title, kind, category, playback_key) values "
                    "('ghost', 't', 'video', 'abstract', 'live/ghost.mp4')")
        problems, _ = backup.drill(self.make())
        self.assertEqual(problems, ["a wallpaper points at a file that isn't there: live/ghost.mp4"])

    def test_a_restore_goes_only_where_nothing_is(self):
        made = self.make()
        target_files = os.path.join(self.root, "restored")
        self.pg.sql("create database restore_target")
        target = backup.with_database(self.pg.url, "restore_target")
        try:
            manifest = backup.restore(made, target, target_files)
            self.assertEqual(backup.check(manifest, target, target_files), [])
            with open(os.path.join(target_files, "live/bbbb.mp4")) as handle:
                self.assertEqual(handle.read(), "video of bbbb")
            # Again, onto what is now there: refused, twice over.
            with self.assertRaises(backup.BackupError):
                backup.restore(made, target, os.path.join(self.root, "elsewhere"))
            with self.assertRaises(backup.BackupError):
                backup.restore(made, backup.with_database(self.pg.url, "postgres"), target_files)
        finally:
            self.pg.sql("drop database restore_target with (force)")

    def test_unchanged_files_are_shared_between_backups_and_old_backups_go(self):
        first = self.make()
        self.file("live/bbbb.mp4", "a new cut of bbbb, longer")
        second = self.make()

        def same(a, b, relative):
            return os.path.samefile(os.path.join(a, "files", relative), os.path.join(b, "files", relative))
        self.assertTrue(same(first, second, "live/aaaa.mp4"))
        self.assertFalse(same(first, second, "live/bbbb.mp4"))
        self.assertEqual(backup.read_manifest(second)["files"]["live/bbbb.mp4"]["sha256"],
                         backup.sha256(os.path.join(self.storage, "live/bbbb.mp4")))
        self.assertEqual(backup.drill(second)[0], [])

        third = self.make(keep=2)
        self.assertEqual(backup.backups_in(self.destination), [second, third])
        # Losing the first backup doesn't hurt the ones that shared its files.
        self.assertEqual(backup.drill(third)[0], [])

    def test_failed_replacement_drill_never_prunes_a_verified_backup(self):
        first = self.make(keep=1)
        real_query = backup.query

        def delete_between_dump_and_copy(url, statement):
            result = real_query(url, statement)
            if url == self.pg.url and statement == "select count(*) from wallpapers":
                self.pg.sql("delete from wallpapers where id = 'aaaa'")
                os.remove(os.path.join(self.storage, "live/aaaa.mp4"))
            return result

        backup.query = delete_between_dump_and_copy
        try:
            with self.assertRaisesRegex(backup.BackupError, "older backups were kept"):
                self.make(keep=1)
        finally:
            backup.query = real_query
        self.assertTrue(os.path.isdir(first))
        self.assertEqual(backup.drill(first)[0], [])
        self.assertEqual(len(backup.backups_in(self.destination)), 2)

    def test_unavailable_drill_never_prunes_previous_backups(self):
        first = self.make()
        real_drill = backup.drill
        def unavailable(_):
            raise backup.BackupError("drill database unavailable")
        backup.drill = unavailable
        try:
            with self.assertRaisesRegex(backup.BackupError, "unavailable"):
                self.make(keep=1)
        finally:
            backup.drill = real_drill
        self.assertTrue(os.path.isdir(first))
        self.assertEqual(backup.drill(first)[0], [])

    def test_a_backup_that_fails_leaves_nothing_half_made(self):
        good = backup.DATABASE_URL
        backup.DATABASE_URL = f"postgres://allset@127.0.0.1:{pgtest.free_port()}/postgres"
        try:
            with self.assertRaises(backup.BackupError):
                self.make()
        finally:
            backup.DATABASE_URL = good
        self.assertEqual(os.listdir(self.destination), [])


if __name__ == "__main__":
    unittest.main()
