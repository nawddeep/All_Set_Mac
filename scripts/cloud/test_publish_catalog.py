"""publish_catalog.py against temporary folders and a throwaway Postgres.

    /usr/bin/python3 -m unittest scripts/cloud/test_publish_catalog.py
"""
import hashlib
import json
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pgtest  # noqa: E402
import publish_catalog  # noqa: E402
from publish_catalog import PublishError, publish  # noqa: E402


def row(id, title="A wallpaper", license="CC0", **changes):
    made = {"id": id, "title": title, "kind": "video", "category": "nature", "tags": ["calm"],
            "playback_key": f"live/{id}.mp4", "still_key": f"stills/{id}.jpg", "thumbnail_key": f"thumbnails/{id}.jpg",
            "duration": 12.5, "width": 1920, "height": 1080, "fps": 30, "content_rating": "Everyone",
            "added_at": "2026-10-01T00:00:00+00:00",
            "provenance": {"license": license, "author": "Someone", "source": "steam-workshop", "workshopId": "123"}}
    made.update(changes)
    return made


class PublishTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="allset-publish-test-")
        self.storage = os.path.join(self.tmp, "storage", "wallpapers")
        self.public = os.path.join(self.tmp, "public")
        os.makedirs(self.storage)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def store(self, relative, content=None, root=None):
        path = os.path.join(root or self.storage, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as handle:
            handle.write(content if content is not None else relative.encode())
        return path

    def store_all(self, id):
        for relative in (f"live/{id}.mp4", f"stills/{id}.jpg", f"thumbnails/{id}.jpg"):
            self.store(relative)

    def catalog(self):
        with open(os.path.join(self.public, "catalog.json")) as handle:
            return json.load(handle)

    def public_files(self):
        return sorted(os.path.relpath(os.path.join(folder, name), self.public)
                      for folder, _, names in os.walk(self.public) for name in names)

    def test_a_published_wallpaper_goes_out_with_its_files_and_checksums(self):
        self.store_all("aaaa")
        report = publish([row("aaaa")], self.storage, self.public)
        self.assertEqual((report["items"], report["revision"], report["skipped"]), (1, 1, []))
        self.assertEqual(self.public_files(), ["catalog.json", "live/aaaa.mp4", "stills/aaaa.jpg", "thumbnails/aaaa.jpg"])
        catalog = self.catalog()
        self.assertEqual((catalog["version"], catalog["revision"], catalog["roots"]), (1, 1, []))
        item = catalog["items"][0]
        self.assertEqual((item["root"], item["file"], item["playback"], item["still"], item["thumbnail"]),
                         ("server", "live/aaaa.mp4", "live/aaaa.mp4", "stills/aaaa.jpg", "thumbnails/aaaa.jpg"))
        self.assertEqual(item["size"], len(b"live/aaaa.mp4"))
        self.assertEqual(item["checksums"]["playback"], hashlib.sha256(b"live/aaaa.mp4").hexdigest())
        self.assertEqual(item["status"], "published")

    def test_only_the_author_and_license_leave_the_provenance(self):
        self.store_all("aaaa")
        publish([row("aaaa", origin_root="5feebe9e", origin_file="1396967200/scene.pkg")], self.storage, self.public)
        item = self.catalog()["items"][0]
        self.assertEqual(item["provenance"], {"license": "CC0", "author": "Someone"})
        with open(os.path.join(self.public, "catalog.json")) as handle:
            text = handle.read()
        for private in ("origin", "scene.pkg", "5feebe9e", "workshopId", "steam-workshop"):
            self.assertNotIn(private, text)

    def test_a_row_without_a_license_is_left_out_and_reported(self):
        for id in ("aaaa", "bbbb", "cccc", "dddd"):
            self.store_all(id)
        rows = [row("aaaa"), row("bbbb", license=None), row("cccc", license="  "), row("dddd", provenance=None)]
        report = publish(rows, self.storage, self.public)
        self.assertEqual([item["id"] for item in self.catalog()["items"]], ["aaaa"])
        self.assertEqual([(id, why) for id, _, why in report["skipped"]],
                         [("bbbb", "no license recorded"), ("cccc", "no license recorded"), ("dddd", "no license recorded")])
        self.assertFalse(os.path.exists(os.path.join(self.public, "live/bbbb.mp4")))

    def test_a_row_whose_file_is_not_in_storage_is_left_out(self):
        self.store("thumbnails/aaaa.jpg")
        report = publish([row("aaaa")], self.storage, self.public)
        self.assertEqual(self.catalog()["items"], [])
        self.assertEqual(report["skipped"], [("aaaa", "A wallpaper", "its file isn't in storage")])
        self.assertEqual(self.public_files(), ["catalog.json"])

    def test_a_still_wallpaper_and_a_missing_thumbnail(self):
        self.store("stills/aaaa.jpg")
        publish([row("aaaa", kind="image", playback_key=None)], self.storage, self.public)
        item = self.catalog()["items"][0]
        self.assertEqual(item["file"], "stills/aaaa.jpg")
        self.assertNotIn("playback", item)
        self.assertNotIn("thumbnail", item)
        self.assertEqual(list(item["checksums"]), ["still"])

    def test_keys_that_leave_storage_or_name_hidden_folders_publish_nothing(self):
        outside = self.store("secret.mp4", root=self.tmp)
        self.store(".retired/aaaa/1/live/aaaa.mp4")
        os.symlink(outside, os.path.join(self.storage, "link.mp4"))
        for key in ("../secret.mp4", outside, ".retired/aaaa/1/live/aaaa.mp4", "link.mp4", "live/../../secret.mp4", ""):
            report = publish([row("aaaa", playback_key=key, still_key=None, thumbnail_key=None)], self.storage, self.public)
            self.assertEqual(report["items"], 0, key)
            self.assertEqual(self.public_files(), ["catalog.json"], key)

    def test_an_unchanged_library_keeps_its_catalog_and_revision(self):
        self.store_all("aaaa")
        publish([row("aaaa")], self.storage, self.public)
        before = os.stat(os.path.join(self.public, "catalog.json"))
        report = publish([row("aaaa")], self.storage, self.public)
        after = os.stat(os.path.join(self.public, "catalog.json"))
        self.assertEqual((report["changed"], report["revision"], report["added"], report["removed"]), (False, 1, [], []))
        self.assertEqual((before.st_ino, before.st_mtime_ns), (after.st_ino, after.st_mtime_ns))

    def test_a_change_raises_the_revision(self):
        self.store_all("aaaa")
        publish([row("aaaa")], self.storage, self.public)
        report = publish([row("aaaa", title="Renamed")], self.storage, self.public)
        self.assertEqual((report["changed"], report["revision"]), (True, 2))
        self.assertEqual(self.catalog()["items"][0]["title"], "Renamed")

    def test_taking_a_wallpaper_down_removes_its_files(self):
        self.store_all("aaaa")
        self.store_all("bbbb")
        publish([row("aaaa"), row("bbbb")], self.storage, self.public)
        report = publish([row("aaaa")], self.storage, self.public)
        self.assertEqual(report["removed"], ["live/bbbb.mp4", "stills/bbbb.jpg", "thumbnails/bbbb.jpg"])
        self.assertEqual(self.public_files(), ["catalog.json", "live/aaaa.mp4", "stills/aaaa.jpg", "thumbnails/aaaa.jpg"])
        # Storage keeps its own copy: only the public one went.
        self.assertTrue(os.path.isfile(os.path.join(self.storage, "live/bbbb.mp4")))
        publish([], self.storage, self.public)
        self.assertEqual(self.public_files(), ["catalog.json"])
        self.assertEqual(os.listdir(self.public), ["catalog.json"])

    def test_a_file_replaced_in_storage_is_replaced_in_public(self):
        self.store_all("aaaa")
        publish([row("aaaa")], self.storage, self.public)
        # As rsync does it: a new file takes the old one's name.
        os.remove(os.path.join(self.storage, "live/aaaa.mp4"))
        self.store("live/aaaa.mp4", b"a new render")
        report = publish([row("aaaa")], self.storage, self.public)
        self.assertEqual(report["added"], ["live/aaaa.mp4"])
        with open(os.path.join(self.public, "live/aaaa.mp4"), "rb") as handle:
            self.assertEqual(handle.read(), b"a new render")
        self.assertEqual(self.catalog()["items"][0]["checksums"]["playback"], hashlib.sha256(b"a new render").hexdigest())

    def test_a_copy_that_is_already_right_is_not_put_again(self):
        self.store_all("aaaa")
        self.store("live/aaaa.mp4", root=self.public)   # same bytes, a file of its own
        self.store("catalog.json", b'{"items": []}', root=self.public)
        report = publish([row("aaaa")], self.storage, self.public)
        self.assertEqual(report["added"], ["stills/aaaa.jpg", "thumbnails/aaaa.jpg"])

    def test_a_dry_run_changes_nothing(self):
        self.store_all("aaaa")
        report = publish([row("aaaa")], self.storage, self.public, dry_run=True)
        self.assertEqual((report["items"], report["revision"], len(report["added"])), (1, 1, 3))
        self.assertFalse(os.path.exists(self.public))
        publish([row("aaaa")], self.storage, self.public)
        report = publish([], self.storage, self.public, dry_run=True)
        self.assertEqual(len(report["removed"]), 3)
        self.assertEqual(len(self.public_files()), 4)

    def test_what_an_interrupted_run_left_is_swept_up(self):
        self.store_all("aaaa")
        publish([row("aaaa")], self.storage, self.public)
        self.store("live/bbbb.mp4.publishing", root=self.public)
        publish([row("aaaa")], self.storage, self.public)
        self.assertNotIn("live/bbbb.mp4.publishing", self.public_files())

    def test_a_folder_that_is_not_a_published_one_is_never_emptied(self):
        precious = self.store("holiday.jpg", root=self.public)
        self.store_all("aaaa")
        with self.assertRaises(PublishError):
            publish([row("aaaa")], self.storage, self.public)
        self.assertTrue(os.path.isfile(precious))
        self.assertEqual(self.public_files(), ["holiday.jpg"])

    def test_public_and_storage_must_be_separate(self):
        self.store_all("aaaa")
        for public in (self.storage, os.path.join(self.storage, "public"), os.path.dirname(self.storage), self.tmp):
            with self.assertRaises(PublishError):
                publish([row("aaaa")], self.storage, public)
        self.assertTrue(os.path.isfile(os.path.join(self.storage, "live/aaaa.mp4")))

    def test_the_app_can_read_what_it_wrote(self):
        """Every key LibraryVideo requires (WallpaperLibrary.swift) is there."""
        self.store_all("aaaa")
        publish([row("aaaa")], self.storage, self.public)
        item = self.catalog()["items"][0]
        for required in ("id", "root", "file"):
            self.assertIsInstance(item[required], str)
        self.assertEqual(item["root"], publish_catalog.LIBRARY_ROOT)


@unittest.skipUnless(pgtest.AVAILABLE, "needs a local Postgres")
class FetchRowsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pg = pgtest.Postgres()

    @classmethod
    def tearDownClass(cls):
        cls.pg.stop()

    def test_only_published_rows_are_read_in_catalog_order(self):
        self.pg.sql("""insert into wallpapers (id, title, kind, category, status, playback_key, provenance) values
            ('aaaa', 'Zebra', 'video', 'nature', 'published', 'live/aaaa.mp4', '{"license": "CC0"}'),
            ('bbbb', 'Quiet', 'video', 'nature', 'quarantined', 'live/bbbb.mp4', '{"license": "CC0"}'),
            ('cccc', 'Broken', 'video', 'nature', 'unsupported', null, null),
            ('dddd', 'Alley', 'image', 'cities', 'published', null, null)""")
        rows = publish_catalog.fetch_rows(self.pg.url, psql=pgtest.PSQL)
        self.assertEqual([r["id"] for r in rows], ["dddd", "aaaa"])
        self.assertEqual(rows[1]["provenance"], {"license": "CC0"})
        self.assertNotIn("origin_file", rows[0])

    def test_a_database_that_is_not_there_is_an_error_not_an_empty_library(self):
        with self.assertRaises(PublishError):
            publish_catalog.fetch_rows("postgres://allset@127.0.0.1:1/nothing", psql=pgtest.PSQL)


if __name__ == "__main__":
    unittest.main()
