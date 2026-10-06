"""Runs sync_catalog.py against a throwaway local Postgres (needs Homebrew's
initdb/pg_ctl; skipped otherwise). Nothing touches the real catalog or database.

    /usr/bin/python3 -m unittest scripts/cloud/test_sync_catalog.py
"""
import contextlib
import io
import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sync_catalog  # noqa: E402

import pgtest  # noqa: E402


@unittest.skipUnless(pgtest.AVAILABLE, "needs a local Postgres")
class SyncCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pg = pgtest.Postgres()
        cls.url = cls.pg.url
        cls.tmp = cls.pg.tmp
        sync_catalog.PSQL = pgtest.PSQL

    @classmethod
    def tearDownClass(cls):
        cls.pg.stop()

    @classmethod
    def psql(cls, sql):
        return cls.pg.sql(sql)

    def sync(self, items):
        library = os.path.join(self.tmp, "library")
        os.makedirs(library, exist_ok=True)
        with open(os.path.join(library, "catalog.json"), "w") as f:
            json.dump({"items": items}, f)
        env = {"DATABASE_URL": self.url, "ALLSET_LIBRARY": library}
        saved = dict(os.environ), sync_catalog.tunnel_is_open
        os.environ.update(env)
        sync_catalog.tunnel_is_open = lambda *a, **k: True
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                sync_catalog.main()
        finally:
            os.environ.clear()
            os.environ.update(saved[0])
            sync_catalog.tunnel_is_open = saved[1]

    def setUp(self):
        self.psql("delete from wallpapers")

    def item(self, id, title):
        return {"id": id, "title": title, "kind": "video", "category": "abstract", "status": "quarantined"}

    def test_a_rerun_keeps_uploaded_storage_keys(self):
        self.sync([self.item("aaaa", "Before")])
        # The upload step fills in where each file lives.
        self.psql("update wallpapers set playback_key = 'live/aaaa.mp4', still_key = 'stills/aaaa.jpg', "
                  "thumbnail_key = 'thumbnails/aaaa.jpg' where id = 'aaaa'")
        self.sync([self.item("aaaa", "After")])
        row = self.psql("select title, playback_key, still_key, thumbnail_key from wallpapers where id = 'aaaa'")
        self.assertEqual(row, "After|live/aaaa.mp4|stills/aaaa.jpg|thumbnails/aaaa.jpg")

    def test_new_rows_start_without_storage_keys(self):
        self.sync([self.item("bbbb", "New")])
        row = self.psql("select title, playback_key is null, still_key is null, thumbnail_key is null from wallpapers where id = 'bbbb'")
        self.assertEqual(row, "New|t|t|t")

    def test_metadata_still_updates(self):
        self.sync([self.item("cccc", "One")])
        changed = dict(self.item("cccc", "Two"), category="nature", status="published")
        self.sync([changed])
        self.assertEqual(self.psql("select title, category, status from wallpapers where id = 'cccc'"), "Two|nature|published")


if __name__ == "__main__":
    unittest.main()
