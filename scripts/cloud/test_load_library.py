"""load_library.py against temporary folders and a throwaway Postgres.

    /usr/bin/python3 -m unittest scripts/cloud/test_load_library.py
"""
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import load_library  # noqa: E402
import pgtest  # noqa: E402
from load_library import LoadError, load  # noqa: E402


def item(id, **changes):
    made = {"id": id, "title": id, "kind": "video", "status": "quarantined",
            "playback": f"live/{id}.mp4", "still": f"stills/{id}.jpg", "thumbnail": f"thumbnails/{id}.jpg"}
    made.update(changes)
    return made


class Folders(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="allset-load-test-")
        self.library = os.path.join(self.tmp, "Library")
        self.storage = os.path.join(self.tmp, "storage", "wallpapers")
        os.makedirs(self.library)
        os.makedirs(self.storage)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def put(self, relative, content=None, root=None):
        path = os.path.join(root or self.library, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as handle:
            handle.write(content if content is not None else relative.encode())
        return path

    def put_all(self, id):
        for relative in (f"live/{id}.mp4", f"stills/{id}.jpg", f"thumbnails/{id}.jpg"):
            self.put(relative)

    def stored(self):
        return sorted(os.path.relpath(os.path.join(folder, name), self.storage)
                      for folder, _, names in os.walk(self.storage) for name in names)


class LoadTests(Folders):
    def test_files_land_at_the_same_paths_and_every_one_gets_a_key(self):
        self.put_all("aaaa")
        report, keys = load([item("aaaa")], self.library, self.storage)
        self.assertEqual(self.stored(), ["live/aaaa.mp4", "stills/aaaa.jpg", "thumbnails/aaaa.jpg"])
        self.assertEqual((report["copied"], report["already"], report["missing"]), (3, 0, 0))
        self.assertEqual(keys, {"aaaa": {"playback_key": "live/aaaa.mp4", "still_key": "stills/aaaa.jpg",
                                         "thumbnail_key": "thumbnails/aaaa.jpg"}})
        with open(os.path.join(self.storage, "live/aaaa.mp4"), "rb") as handle:
            self.assertEqual(handle.read(), b"live/aaaa.mp4")

    def test_a_second_run_copies_nothing_and_a_changed_file_is_copied_again(self):
        self.put_all("aaaa")
        load([item("aaaa")], self.library, self.storage)
        report, keys = load([item("aaaa")], self.library, self.storage)
        self.assertEqual((report["copied"], report["already"]), (0, 3))
        self.assertEqual(len(keys["aaaa"]), 3)
        self.put("live/aaaa.mp4", b"a longer new render")
        report, _ = load([item("aaaa")], self.library, self.storage)
        self.assertEqual(report["copied"], 1)
        with open(os.path.join(self.storage, "live/aaaa.mp4"), "rb") as handle:
            self.assertEqual(handle.read(), b"a longer new render")

    def test_a_file_freed_from_this_mac_keeps_its_copy_in_storage_and_its_key(self):
        self.put("thumbnails/aaaa.jpg")
        self.put("live/aaaa.mp4", b"the server's copy", root=self.storage)
        report, keys = load([item("aaaa")], self.library, self.storage)
        self.assertEqual(keys["aaaa"], {"playback_key": "live/aaaa.mp4", "thumbnail_key": "thumbnails/aaaa.jpg"})
        self.assertEqual((report["copied"], report["missing"]), (1, 1))   # the still is nowhere
        with open(os.path.join(self.storage, "live/aaaa.mp4"), "rb") as handle:
            self.assertEqual(handle.read(), b"the server's copy")

    def test_unsupported_entries_and_paths_out_of_the_library_are_not_loaded(self):
        self.put_all("aaaa")
        outside = self.put("secret.mp4", root=self.tmp)
        items = [item("aaaa", status="unsupported"),
                 item("bbbb", playback="../secret.mp4", still=outside, thumbnail=".hidden/bbbb.jpg")]
        self.put(".hidden/bbbb.jpg")
        report, keys = load(items, self.library, self.storage)
        self.assertEqual((self.stored(), keys, report["copied"]), ([], {}, 0))

    def test_a_dry_run_copies_nothing_but_says_what_it_would(self):
        self.put_all("aaaa")
        report, keys = load([item("aaaa")], self.library, self.storage, dry_run=True)
        self.assertEqual((report["copied"], self.stored(), len(keys["aaaa"])), (3, [], 3))

    def test_the_library_and_storage_must_be_separate(self):
        self.put_all("aaaa")
        for storage in (self.library, os.path.join(self.library, "live"), self.tmp):
            with self.assertRaises(LoadError):
                load([item("aaaa")], self.library, storage)

    def test_two_wallpapers_sharing_a_file_copy_it_once(self):
        self.put_all("aaaa")
        report, keys = load([item("aaaa"), item("bbbb", playback="live/aaaa.mp4", still=None, thumbnail=None)],
                            self.library, self.storage)
        self.assertEqual(report["copied"], 3)
        self.assertEqual(keys["bbbb"], {"playback_key": "live/aaaa.mp4"})


@unittest.skipUnless(pgtest.AVAILABLE, "needs a local Postgres")
class SetKeysTests(Folders):
    @classmethod
    def setUpClass(cls):
        cls.pg = pgtest.Postgres()

    @classmethod
    def tearDownClass(cls):
        cls.pg.stop()

    def setUp(self):
        super().setUp()
        self.pg.sql("delete from wallpapers")
        self.pg.sql("""insert into wallpapers (id, title, kind, category, status, playback_key, still_key) values
            ('aaaa', 'A', 'video', 'nature', 'quarantined', null, null),
            ('bbbb', 'B', 'video', 'nature', 'published', 'live/old.mp4', 'stills/kept.jpg'),
            ('cccc', 'C', 'video', 'nature', 'quarantined', null, null)""")

    def row(self, id):
        return self.pg.sql(f"select playback_key, still_key, thumbnail_key, status, uploaded_at is not null from wallpapers where id = '{id}'")

    def test_keys_are_set_for_what_was_loaded_and_nothing_else_changes(self):
        keys = {"aaaa": {"playback_key": "live/aaaa.mp4", "thumbnail_key": "thumbnails/aaaa.jpg"},
                "bbbb": {"playback_key": "live/bbbb.mp4"},
                "zzzz": {"playback_key": "live/zzzz.mp4"}}   # not in the database
        self.assertEqual(load_library.set_keys(self.pg.url, keys, psql=pgtest.PSQL), 2)
        self.assertEqual(self.row("aaaa"), "live/aaaa.mp4||thumbnails/aaaa.jpg|quarantined|t")
        # A key with no file this time keeps what it had; the status is never touched.
        self.assertEqual(self.row("bbbb"), "live/bbbb.mp4|stills/kept.jpg||published|t")
        self.assertEqual(self.row("cccc"), "|||quarantined|f")
        self.assertEqual(self.pg.sql("select count(*) from wallpapers"), "3")

    def test_an_odd_path_is_data_not_sql(self):
        keys = {"aaaa": {"playback_key": "live/it's'; drop table wallpapers; --.mp4"}}
        self.assertEqual(load_library.set_keys(self.pg.url, keys, psql=pgtest.PSQL), 1)
        self.assertEqual(self.pg.sql("select playback_key from wallpapers where id = 'aaaa'"),
                         "live/it's'; drop table wallpapers; --.mp4")

    def test_nothing_to_set_is_not_an_error(self):
        self.assertEqual(load_library.set_keys(self.pg.url, {}, psql=pgtest.PSQL), 0)


if __name__ == "__main__":
    unittest.main()
