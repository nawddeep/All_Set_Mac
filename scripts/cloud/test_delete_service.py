"""The delete service against a throwaway Postgres and storage folder.

    /usr/bin/python3 -m unittest scripts/cloud/test_delete_service.py
"""
import http.client
import json
import os
import shutil
import sys
import tempfile
import threading
import unittest
from http.server import HTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import delete_service  # noqa: E402
import pgtest  # noqa: E402

TOKEN = "test-token"


@unittest.skipUnless(pgtest.AVAILABLE, "needs a local Postgres")
class DeleteServiceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pg = pgtest.Postgres()
        delete_service.DATABASE_URL = cls.pg.url
        delete_service.PSQL = pgtest.PSQL
        delete_service.Handler.token = TOKEN
        cls.server = HTTPServer(("127.0.0.1", 0), delete_service.Handler)
        cls.port = cls.server.server_address[1]
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.pg.stop()

    def setUp(self):
        self.storage = tempfile.mkdtemp(prefix="allset-storage-test-")
        delete_service.STORAGE = self.storage
        self.pg.sql("drop trigger if exists refuse_delete on wallpapers; delete from wallpapers")

    def tearDown(self):
        shutil.rmtree(self.storage, ignore_errors=True)

    # Helpers

    def file(self, relative, content="x"):
        path = os.path.join(self.storage, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as handle:
            handle.write(content)
        return path

    def exists(self, relative):
        return os.path.exists(os.path.join(self.storage, relative))

    def row(self, item_id, playback=None, still=None, thumbnail=None):
        def value(v):
            return "null" if v is None else "'" + v + "'"
        self.pg.sql(f"insert into wallpapers (id, title, kind, category, playback_key, still_key, thumbnail_key) values "
                    f"('{item_id}', 't', 'video', 'abstract', {value(playback)}, {value(still)}, {value(thumbnail)})")

    def has_row(self, item_id):
        return self.pg.sql(f"select count(*) from wallpapers where id = '{item_id}'") == "1"

    def request(self, body, token=TOKEN, raw=None, headers=None):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        data = raw if raw is not None else json.dumps(body).encode()
        all_headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
        all_headers.update(headers or {})
        connection.request("DELETE", "/wallpaper", body=data, headers=all_headers)
        response = connection.getresponse()
        payload = response.read()
        connection.close()
        return response.status, (json.loads(payload) if payload else None)

    # Deleting

    def test_deletes_the_wallpapers_own_files_and_row(self):
        self.row("aaaa", playback="live/aaaa.mp4")
        for relative in ("live/aaaa.mp4", "stills/aaaa.jpg", "thumbnails/aaaa.jpg"):
            self.file(relative)
        status, body = self.request({"id": "aaaa"})
        self.assertEqual(status, 200)
        self.assertEqual(sorted(body["removedFiles"]), ["live/aaaa.mp4", "stills/aaaa.jpg", "thumbnails/aaaa.jpg"])
        self.assertFalse(self.has_row("aaaa"))
        for relative in ("live/aaaa.mp4", "stills/aaaa.jpg", "thumbnails/aaaa.jpg"):
            self.assertFalse(self.exists(relative))
        self.assertFalse(os.path.exists(delete_service.trash_dir("aaaa")))

    def test_paths_in_the_request_are_ignored(self):
        """The audit's reproduction: a request for one id naming another's file."""
        self.row("aaaa")
        self.row("bbbb")
        self.file("live/aaaa.mp4")
        self.file("live/bbbb.mp4")
        self.file("unrelated.mp4")
        status, _ = self.request({"id": "aaaa", "paths": ["live/bbbb.mp4", "unrelated.mp4"]})
        self.assertEqual(status, 200)
        self.assertFalse(self.exists("live/aaaa.mp4"))
        self.assertTrue(self.exists("live/bbbb.mp4"))
        self.assertTrue(self.exists("unrelated.mp4"))
        self.assertTrue(self.has_row("bbbb"))

    def test_a_key_another_wallpaper_uses_is_kept(self):
        self.row("aaaa", playback="shared/loop.mp4")
        self.row("bbbb", playback="shared/loop.mp4")
        self.file("shared/loop.mp4")
        status, _ = self.request({"id": "aaaa"})
        self.assertEqual(status, 200)
        self.assertTrue(self.exists("shared/loop.mp4"))

    def test_a_key_only_this_wallpaper_uses_goes_with_it(self):
        self.row("aaaa", playback="shared/only-a.mp4")
        self.file("shared/only-a.mp4")
        self.assertEqual(self.request({"id": "aaaa"})[0], 200)
        self.assertFalse(self.exists("shared/only-a.mp4"))

    def test_a_file_named_after_one_wallpaper_but_used_by_another_is_kept(self):
        """Review R6: B also plays live/aaaa.mp4; deleting A must leave it."""
        self.row("aaaa", playback="live/aaaa.mp4")
        self.row("bbbb", playback="live/aaaa.mp4")
        self.file("live/aaaa.mp4", "shared")
        self.file("thumbnails/aaaa.jpg")
        status, body = self.request({"id": "aaaa"})
        self.assertEqual(status, 200)
        self.assertTrue(self.exists("live/aaaa.mp4"))
        self.assertNotIn("live/aaaa.mp4", body["removedFiles"])
        self.assertFalse(self.exists("thumbnails/aaaa.jpg"))
        self.assertFalse(self.has_row("aaaa"))
        self.assertTrue(self.has_row("bbbb"))

    def test_a_file_another_row_starts_using_during_the_delete_goes_back(self):
        """Recheck S1, its reproduction: right after the delete's reference check
        said "nobody else", a writer that takes no lock points B at A's file.
        The delete used to answer 200 and destroy the file B now plays."""
        self.row("aaaa", playback="live/aaaa.mp4")
        self.row("bbbb")
        self.file("live/aaaa.mp4", "original")
        real = delete_service.delete_row_and_find_shared

        def check_then_reference(item_id, relatives):
            shared = real(item_id, relatives)
            self.assertEqual(shared, [])
            self.pg.sql("update wallpapers set playback_key = 'live/aaaa.mp4' where id = 'bbbb'")
            return shared
        delete_service.delete_row_and_find_shared = check_then_reference
        try:
            status, body = self.request({"id": "aaaa"})
        finally:
            delete_service.delete_row_and_find_shared = real
        self.assertEqual(status, 200)
        self.assertFalse(self.has_row("aaaa"))
        self.assertEqual(self.pg.sql("select playback_key from wallpapers where id = 'bbbb'"), "live/aaaa.mp4")
        with open(os.path.join(self.storage, "live/aaaa.mp4")) as handle:
            self.assertEqual(handle.read(), "original")
        self.assertNotIn("live/aaaa.mp4", body["removedFiles"])
        self.assertIn("live/aaaa.mp4", body["keptBecauseShared"])

    def test_a_reference_written_after_the_delete_answered_gets_its_file_back(self):
        """Recheck S1: later still, with the delete long finished. The file is
        retired, not destroyed, so the next sweep puts it back."""
        self.row("aaaa", playback="live/aaaa.mp4")
        self.row("bbbb")
        self.file("live/aaaa.mp4", "original")
        self.assertEqual(self.request({"id": "aaaa"})[0], 200)
        self.assertFalse(self.exists("live/aaaa.mp4"))

        self.pg.sql("update wallpapers set playback_key = 'live/aaaa.mp4' where id = 'bbbb'")
        restored, removed = delete_service.sweep_retired()
        self.assertEqual((restored, removed), (["live/aaaa.mp4"], []))
        with open(os.path.join(self.storage, "live/aaaa.mp4")) as handle:
            self.assertEqual(handle.read(), "original")
        self.assertFalse(os.path.exists(delete_service.retired_dir("aaaa")))

    def test_a_writer_holding_the_catalog_lock_is_waited_for(self):
        """Recheck S1, the coordinated case: a writer that takes the catalog lock
        and commits a reference while the delete is under way is seen by the
        delete's own check, which waits for it."""
        import subprocess
        import time
        import catalog_lock
        self.row("aaaa", playback="live/aaaa.mp4")
        self.row("bbbb")
        self.file("live/aaaa.mp4", "original")
        writer = subprocess.Popen(
            [pgtest.PSQL, self.pg.url, "-q", "-v", "ON_ERROR_STOP=1", "-c",
             f"begin; select pg_advisory_xact_lock({catalog_lock.ASSET_LOCK}); "
             "update wallpapers set playback_key = 'live/aaaa.mp4' where id = 'bbbb'; "
             "select pg_sleep(1.2); commit;"], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        try:
            # Once the writer holds the lock, nobody else can take it.
            for _ in range(100):
                if self.pg.sql(f"select pg_try_advisory_lock({catalog_lock.ASSET_LOCK})") == "f":
                    break
                time.sleep(0.02)
            else:
                self.fail("the writer never took the lock")
            started = time.monotonic()
            status, body = self.request({"id": "aaaa"})
            waited = time.monotonic() - started
        finally:
            self.assertEqual(writer.wait(timeout=20), 0, writer.stderr.read())
            writer.stderr.close()
        self.assertEqual(status, 200)
        self.assertGreater(waited, 0.5)
        self.assertTrue(self.exists("live/aaaa.mp4"))
        self.assertEqual(body["keptBecauseShared"], ["live/aaaa.mp4"])
        self.assertEqual(body["removedFiles"], [])

    def retired_names(self, item_id):
        return sorted(name for _, _, names in os.walk(delete_service.retired_dir(item_id)) for name in names)

    def test_deleted_files_are_kept_for_the_retention_then_removed(self):
        import time
        self.row("aaaa", playback="live/aaaa.mp4")
        self.file("live/aaaa.mp4", "original")
        status, body = self.request({"id": "aaaa"})
        self.assertEqual((status, body["recoverableDays"]), (200, delete_service.RETENTION_DAYS))
        batches = os.listdir(delete_service.retired_dir("aaaa"))
        self.assertEqual(len(batches), 1)
        held = os.path.join(delete_service.retired_dir("aaaa"), batches[0], "live/aaaa.mp4")
        with open(held) as handle:
            self.assertEqual(handle.read(), "original")

        day = 86400
        self.assertEqual(delete_service.sweep_retired(now=time.time() + (delete_service.RETENTION_DAYS - 1) * day), ([], []))
        self.assertTrue(os.path.exists(held))
        self.assertEqual(delete_service.sweep_retired(now=time.time() + (delete_service.RETENTION_DAYS + 1) * day),
                         ([], ["live/aaaa.mp4"]))
        self.assertFalse(os.path.exists(delete_service.retired_dir("aaaa")))

    def test_a_sweep_that_cant_ask_the_database_removes_nothing(self):
        import time
        self.file("live/aaaa.mp4", "original")
        self.assertEqual(self.request({"id": "aaaa"})[0], 200)
        good = delete_service.DATABASE_URL
        delete_service.DATABASE_URL = f"postgres://allset@127.0.0.1:{pgtest.free_port()}/postgres"
        try:
            self.assertEqual(delete_service.sweep_retired(now=time.time() + 365 * 86400), ([], []))
        finally:
            delete_service.DATABASE_URL = good
        self.assertEqual(self.retired_names("aaaa"), ["aaaa.mp4"])

    # Second recheck T1: the final purge

    def retired_long_ago(self, relative="live/aaaa.mp4", item_id="aaaa", content="original"):
        """A file retired longer ago than the retention, so the next sweep may purge it."""
        import time
        stamp = time.time_ns() - int((delete_service.RETENTION_DAYS + 1) * 86400 * 1e9)
        return self.file(os.path.join(".retired", item_id, str(stamp), relative), content)

    def test_a_purge_keeps_the_catalog_lock_from_its_check_to_its_removal(self):
        """The recheck's reproduction: right after the purge's reference check
        says "nobody", a writer that takes the catalog lock points B at the file.
        The purge used to hold nothing, so that commit landed between its check
        and its removal, and B was left pointing at a destroyed file."""
        import subprocess
        import time
        import catalog_lock
        self.row("bbbb")
        self.retired_long_ago()
        real = delete_service.referenced_keys
        seen = {}

        def check_then_a_writer_arrives(relatives):
            found = real(relatives)
            seen["writer"] = subprocess.Popen(
                [pgtest.PSQL, self.pg.url, "-q", "-v", "ON_ERROR_STOP=1", "-c",
                 f"begin; select pg_advisory_xact_lock({catalog_lock.ASSET_LOCK}); "
                 "update wallpapers set playback_key = 'live/aaaa.mp4' where id = 'bbbb'; commit;"],
                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            time.sleep(0.6)  # ample for it to commit, unless something holds it back
            seen["committed before the removal"] = (
                self.pg.sql("select coalesce(playback_key, '') from wallpapers where id = 'bbbb'") == "live/aaaa.mp4")
            return found
        delete_service.referenced_keys = check_then_a_writer_arrives
        try:
            delete_service.sweep_retired()
        finally:
            delete_service.referenced_keys = real
            self.assertEqual(seen["writer"].wait(timeout=20), 0, seen["writer"].stderr.read())
            seen["writer"].stderr.close()
        self.assertFalse(seen["committed before the removal"])

    def test_a_writer_that_committed_first_stops_the_purge(self):
        """The other order: the writer holds the lock when the purge starts. The
        purge waits for it, sees the reference, and puts the file back."""
        import subprocess
        import time
        import catalog_lock
        self.row("bbbb")
        self.retired_long_ago()
        writer = subprocess.Popen(
            [pgtest.PSQL, self.pg.url, "-q", "-v", "ON_ERROR_STOP=1", "-c",
             f"begin; select pg_advisory_xact_lock({catalog_lock.ASSET_LOCK}); "
             "update wallpapers set playback_key = 'live/aaaa.mp4' where id = 'bbbb'; "
             "select pg_sleep(1.0); commit;"], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        try:
            for _ in range(100):
                if self.pg.sql(f"select pg_try_advisory_lock({catalog_lock.ASSET_LOCK})") == "f":
                    break
                time.sleep(0.02)
            else:
                self.fail("the writer never took the lock")
            restored, removed = delete_service.sweep_retired()
        finally:
            self.assertEqual(writer.wait(timeout=20), 0, writer.stderr.read())
            writer.stderr.close()
        self.assertEqual((restored, removed), (["live/aaaa.mp4"], []))
        with open(os.path.join(self.storage, "live/aaaa.mp4")) as handle:
            self.assertEqual(handle.read(), "original")

    def test_the_supported_writer_brings_a_retired_file_back_when_it_references_it(self):
        self.row("bbbb")
        self.retired_long_ago()
        self.assertIsNone(delete_service.reference_asset("bbbb", "playback_key", "live/aaaa.mp4"))
        self.assertEqual(self.pg.sql("select playback_key from wallpapers where id = 'bbbb'"), "live/aaaa.mp4")
        with open(os.path.join(self.storage, "live/aaaa.mp4")) as handle:
            self.assertEqual(handle.read(), "original")
        # Referenced and in place: the purge has nothing to take.
        self.assertEqual(delete_service.sweep_retired(), ([], []))
        self.assertTrue(self.exists("live/aaaa.mp4"))

    def test_the_supported_writer_never_references_a_file_that_isnt_there(self):
        self.row("bbbb")
        self.assertIn("no such file", delete_service.reference_asset("bbbb", "playback_key", "live/aaaa.mp4"))
        self.assertIn("outside", delete_service.reference_asset("bbbb", "playback_key", "../elsewhere.mp4"))
        self.assertIn("column", delete_service.reference_asset("bbbb", "title", "live/aaaa.mp4"))
        self.file("live/aaaa.mp4")
        self.assertIn("no wallpaper", delete_service.reference_asset("zzzz", "playback_key", "live/aaaa.mp4"))
        self.assertEqual(self.pg.sql("select coalesce(playback_key, '-') from wallpapers where id = 'bbbb'"), "-")

    def test_the_supported_writer_racing_the_purge_leaves_no_dangling_reference(self):
        """It arrives between the purge's check and its removal, waits for the
        lock, then finds the file gone and refuses: B never points at nothing."""
        import threading
        import time
        self.row("bbbb")
        self.retired_long_ago()
        real = delete_service.referenced_keys
        seen = {}

        def check_then_the_writer_arrives(relatives):
            found = real(relatives)
            def write():
                seen["answer"] = delete_service.reference_asset("bbbb", "playback_key", "live/aaaa.mp4")
            seen["thread"] = threading.Thread(target=write)
            seen["thread"].start()
            time.sleep(0.4)
            return found
        delete_service.referenced_keys = check_then_the_writer_arrives
        try:
            restored, removed = delete_service.sweep_retired()
        finally:
            delete_service.referenced_keys = real
            seen["thread"].join(timeout=30)
        self.assertEqual((restored, removed), ([], ["live/aaaa.mp4"]))
        self.assertIn("no such file", seen["answer"])
        self.assertEqual(self.pg.sql("select coalesce(playback_key, '-') from wallpapers where id = 'bbbb'"), "-")

    def test_rollback_never_discards_an_original_when_its_place_was_taken(self):
        """Review R7: the destination is recreated while the delete is staged and
        the database step then fails: the original stays held, nothing is lost."""
        self.row("aaaa")
        self.file("live/aaaa.mp4", "original")
        real = delete_service.delete_row_and_find_shared

        def recreate_then_fail(item_id, relatives):
            self.file("live/aaaa.mp4", "replacement")
            raise delete_service.DatabaseError("database says no")
        delete_service.delete_row_and_find_shared = recreate_then_fail
        try:
            status, body = self.request({"id": "aaaa"})
        finally:
            delete_service.delete_row_and_find_shared = real
        self.assertEqual(status, 503)
        self.assertEqual(body.get("conflicts"), ["live/aaaa.mp4"])
        with open(os.path.join(self.storage, "live/aaaa.mp4")) as handle:
            self.assertEqual(handle.read(), "replacement")
        held = os.path.join(delete_service.trash_dir("aaaa"), "live/aaaa.mp4")
        with open(held) as handle:
            self.assertEqual(handle.read(), "original")
        self.assertTrue(self.has_row("aaaa"))

    def test_settling_a_quarantine_keeps_originals_whose_place_was_taken(self):
        self.row("aaaa")
        self.file(".trash/aaaa/live/aaaa.mp4", "original")
        self.file("live/aaaa.mp4", "replacement")
        delete_service.settle_all_quarantines()
        with open(os.path.join(delete_service.trash_dir("aaaa"), "live/aaaa.mp4")) as handle:
            self.assertEqual(handle.read(), "original")

    def test_an_unknown_id_is_404_and_touches_nothing(self):
        self.file("live/bbbb.mp4")
        status, _ = self.request({"id": "zzzz"})
        self.assertEqual(status, 404)
        self.assertTrue(self.exists("live/bbbb.mp4"))

    def test_files_without_a_row_are_still_removed_then_404_after(self):
        """A retry after an earlier attempt removed the row but not every file."""
        self.file("live/aaaa.mp4")
        self.assertEqual(self.request({"id": "aaaa"})[0], 200)
        self.assertFalse(self.exists("live/aaaa.mp4"))
        self.assertEqual(self.request({"id": "aaaa"})[0], 404)

    # The database failing

    def test_a_database_failure_restores_the_files_and_a_retry_finishes(self):
        self.row("aaaa")
        self.file("live/aaaa.mp4", "precious")
        self.pg.sql("create or replace function refuse() returns trigger language plpgsql as "
                    "$$ begin raise exception 'database says no'; end $$; "
                    "create trigger refuse_delete before delete on wallpapers for each row execute function refuse()")
        status, body = self.request({"id": "aaaa"})
        self.assertEqual(status, 503)
        self.assertIn("files restored", body["error"])
        self.assertTrue(self.exists("live/aaaa.mp4"))
        with open(os.path.join(self.storage, "live/aaaa.mp4")) as handle:
            self.assertEqual(handle.read(), "precious")
        self.assertTrue(self.has_row("aaaa"))
        self.assertFalse(os.path.exists(delete_service.trash_dir("aaaa")))

        self.pg.sql("drop trigger refuse_delete on wallpapers")
        self.assertEqual(self.request({"id": "aaaa"})[0], 200)
        self.assertFalse(self.exists("live/aaaa.mp4"))
        self.assertFalse(self.has_row("aaaa"))

    def test_an_unreachable_database_deletes_nothing(self):
        self.row("aaaa")
        self.file("live/aaaa.mp4")
        good = delete_service.DATABASE_URL
        delete_service.DATABASE_URL = f"postgres://allset@127.0.0.1:{pgtest.free_port()}/postgres"
        try:
            self.assertEqual(self.request({"id": "aaaa"})[0], 503)
        finally:
            delete_service.DATABASE_URL = good
        self.assertTrue(self.exists("live/aaaa.mp4"))
        self.assertTrue(self.has_row("aaaa"))

    # A crash mid-delete

    def test_a_quarantine_with_its_row_still_there_goes_back(self):
        self.row("aaaa")
        self.file(".trash/aaaa/live/aaaa.mp4", "held")
        delete_service.settle_all_quarantines()
        self.assertTrue(self.exists("live/aaaa.mp4"))
        self.assertFalse(os.path.exists(delete_service.trash_dir("aaaa")))

    def test_a_quarantine_whose_row_is_gone_is_finished(self):
        self.file(".trash/aaaa/live/aaaa.mp4", "held")
        delete_service.settle_all_quarantines()
        self.assertFalse(self.exists("live/aaaa.mp4"))
        self.assertFalse(os.path.exists(delete_service.trash_dir("aaaa")))

    # Malformed requests

    def test_malformed_requests_are_refused_and_the_service_keeps_running(self):
        self.row("aaaa")
        self.file("live/aaaa.mp4")
        cases = [
            (b"[1, 2]", 400),                       # an array, not an object
            (b'{"id": 5}', 400),                    # a number id
            (b'{"id": "../etc"}', 400),             # not an id
            (b'{"paths": ["live/aaaa.mp4"]}', 400),  # no id
            (b"not json", 400),
            (b"", 400),
        ]
        for raw, expected in cases:
            with self.subTest(raw=raw):
                self.assertEqual(self.request(None, raw=raw)[0], expected)
        too_big = b'{"id": "aaaa", "pad": "' + b"x" * (delete_service.MAX_BODY + 10) + b'"}'
        self.assertEqual(self.request(None, raw=too_big)[0], 413)
        self.assertEqual(self.request({"id": "aaaa"}, token="wrong")[0], 401)
        # Nothing above deleted anything, and the service still answers.
        self.assertTrue(self.exists("live/aaaa.mp4"))
        self.assertEqual(self.request({"id": "aaaa"})[0], 200)


if __name__ == "__main__":
    unittest.main()
