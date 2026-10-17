"""The catalog API against a throwaway Postgres and storage folder.

    /usr/bin/python3 -m unittest scripts/cloud/test_catalog_service.py
"""
import http.client
import json
import os
import shutil
import sys
import tempfile
import threading
import time
import unittest
from http.server import ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import accounts  # noqa: E402
import catalog_service  # noqa: E402
import pgtest  # noqa: E402



class RangeTests(unittest.TestCase):
    def test_ranges(self):
        parse = catalog_service.parse_range
        self.assertIsNone(parse(None, 100))
        self.assertEqual(parse("bytes=0-9", 100), (0, 9))
        self.assertEqual(parse("bytes=90-", 100), (90, 99))
        self.assertEqual(parse("bytes=-10", 100), (90, 99))
        self.assertEqual(parse("bytes=95-500", 100), (95, 99))
        self.assertEqual(parse("bytes=100-", 100), "invalid")
        self.assertEqual(parse("bytes=5-2", 100), "invalid")
        self.assertIsNone(parse("bytes=0-1,5-6", 100))  # multiple ranges: whole file
        self.assertIsNone(parse("items=0-1", 100))


@unittest.skipUnless(pgtest.AVAILABLE, "needs a local Postgres")
class CatalogServiceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pg = pgtest.Postgres()
        catalog_service.DATABASE_URL = cls.pg.url
        catalog_service.PSQL = pgtest.PSQL
        cls.accounts = accounts.Accounts(catalog_service.query)
        catalog_service.Handler.accounts = cls.accounts
        password = cls.accounts.invite("tester@example.com")
        session, _ = cls.accounts.sign_in("tester@example.com", password)
        cls.token = cls.accounts.change_password(session, "a-long-enough-password")
        cls.storage = tempfile.mkdtemp(prefix="allset-catalog-test-")
        catalog_service.STORAGE = cls.storage
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), catalog_service.Handler)
        cls.port = cls.server.server_address[1]
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        for item_id, status in (("pub1", "published"), ("quar1", "quarantined")):
            cls.pg.sql(f"insert into wallpapers (id, title, kind, category, status, playback_key) values "
                       f"('{item_id}', '{item_id}', 'video', 'abstract', '{status}', 'live/{item_id}.mp4')")
            os.makedirs(os.path.join(cls.storage, "live"), exist_ok=True)
            with open(os.path.join(cls.storage, f"live/{item_id}.mp4"), "wb") as handle:
                handle.write(bytes(range(100)))

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.pg.stop()
        shutil.rmtree(cls.storage, ignore_errors=True)

    def setUp(self):
        catalog_service.Handler.include_quarantined = False
        # These tests change rows straight in the database, not through sync_catalog,
        # so nothing touches the changed marker: start each from an empty cache.
        catalog_service.CACHE.clear()

    def get(self, path, headers=None, token=None):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        connection.request("GET", path, headers={"Authorization": f"Bearer {self.token if token is None else token}", **(headers or {})})
        response = connection.getresponse()
        body = response.read()
        result = (response.status, dict(response.getheaders()), body)
        connection.close()
        return result

    def test_only_published_wallpapers_are_listed_and_served(self):
        status, _, body = self.get("/catalog")
        self.assertEqual(status, 200)
        self.assertEqual([item["id"] for item in json.loads(body)], ["pub1"])
        self.assertEqual(self.get("/file/pub1")[0], 200)
        self.assertEqual(self.get("/file/quar1")[0], 404)

    def test_quarantined_ones_only_when_explicitly_included(self):
        catalog_service.Handler.include_quarantined = True
        _, _, body = self.get("/catalog")
        self.assertEqual(sorted(item["id"] for item in json.loads(body)), ["pub1", "quar1"])
        self.assertEqual(self.get("/file/quar1")[0], 200)

    def test_a_download_can_resume(self):
        status, headers, body = self.get("/file/pub1", headers={"Range": "bytes=90-"})
        self.assertEqual(status, 206)
        self.assertEqual(headers["Content-Range"], "bytes 90-99/100")
        self.assertEqual(body, bytes(range(90, 100)))
        status, headers, _ = self.get("/file/pub1", headers={"Range": "bytes=500-"})
        self.assertEqual(status, 416)
        status, headers, body = self.get("/file/pub1")
        self.assertEqual((status, len(body), headers["Accept-Ranges"]), (200, 100, "bytes"))

    def test_bad_requests(self):
        self.assertEqual(self.get("/catalog", token="wrong")[0], 401)
        self.assertEqual(self.get("/file/../../etc")[0], 400)
        self.assertEqual(self.get("/file/nope")[0], 404)
        self.assertEqual(self.get("/elsewhere")[0], 404)

    def test_the_api_key_is_accepted_wherever_a_session_is(self):
        catalog_service.Handler.key = "the-permanent-key"
        try:
            self.assertEqual(self.get("/me", token="the-permanent-key")[0], 200)
            self.assertEqual(self.get("/catalog", token="the-permanent-key")[0], 200)
            self.assertEqual(self.get("/file/pub1", token="the-permanent-key")[0], 200)
            self.assertEqual(self.get("/library", token="the-permanent-key")[0], 200)
            self.assertEqual(self.get("/me", token="the-permanent-ke")[0], 401)
            self.assertEqual(self.get("/library", token="")[0], 401)
        finally:
            catalog_service.Handler.key = ""
        # With no key on the server, nothing but a session gets in: not even an empty token.
        self.assertEqual(self.get("/me", token="the-permanent-key")[0], 401)
        self.assertEqual(self.get("/me", token="")[0], 401)

    def test_the_library_is_the_apps_catalog_with_each_files_place_on_the_server(self):
        self.pg.sql("insert into wallpapers (id, title, kind, category, tags, status, playback_key, still_key, "
                    "thumbnail_key, origin_root, origin_file, size_bytes) values ('lib1', 'Lib', 'video', 'zz-library', "
                    "'{rain,night}', 'published', 'live/lib1.mp4', 'stills/lib1.jpg', 'thumbnails/gone.jpg', "
                    "'drive', '/Volumes/Drive/lib1.mp4', 100), "
                    "('lib2', 'Not uploaded', 'video', 'zz-library', '{}', 'published', 'live/lib2.mp4', null, null, null, null, 1)")
        os.makedirs(os.path.join(self.storage, "stills"), exist_ok=True)
        for name in ("live/lib1.mp4", "stills/lib1.jpg"):
            with open(os.path.join(self.storage, name), "wb") as handle:
                handle.write(b"x")
        try:
            status, _, body = self.get("/library")
            library = json.loads(body)
            self.assertEqual((status, library["version"], library["roots"]), (200, 1, []))
            items = {item["id"]: item for item in library["items"]}
            # Published only, and only what's on this server (quar1 and lib2 are not).
            self.assertEqual(sorted(items), ["lib1", "pub1"])
            self.assertEqual(items["lib1"], {
                "id": "lib1", "title": "Lib", "kind": "video", "category": "zz-library", "tags": ["rain", "night"],
                "root": "server", "file": "live/lib1.mp4", "playback": "live/lib1.mp4", "still": "stills/lib1.jpg",
                "size": 100, "status": "published"})
            self.assertNotIn("/Volumes", body.decode())
            catalog_service.Handler.include_quarantined = True
            self.assertIn("quar1", [item["id"] for item in json.loads(self.get("/library")[2])["items"]])
        finally:
            self.pg.sql("delete from wallpapers where category = 'zz-library'")

    def test_the_catalog_can_be_read_a_page_at_a_time(self):
        """Paging is opt-in: the body is the same list, the headers say how to go on."""
        for index in range(5):
            item_id = f"page{index}"
            self.pg.sql(f"insert into wallpapers (id, title, kind, category, status, playback_key) values "
                        f"('{item_id}', 'p{index}', 'video', 'zz-pages', 'published', 'live/{item_id}.mp4')")
            with open(os.path.join(self.storage, f"live/{item_id}.mp4"), "wb") as handle:
                handle.write(b"x")
        try:
            whole = [item["id"] for item in json.loads(self.get("/catalog")[2])]
            self.assertEqual(len(whole), 6)

            collected, offset, pages = [], 0, 0
            while offset is not None:
                status, headers, body = self.get(f"/catalog?limit=4&offset={offset}")
                self.assertEqual((status, headers["X-Total-Count"]), (200, "6"))
                collected += [item["id"] for item in json.loads(body)]
                offset = headers.get("X-Next-Offset")
                pages += 1
            self.assertEqual((collected, pages), (whole, 2))

            for bad in ("limit=0", "limit=501", "limit=many", "offset=-1"):
                self.assertEqual(self.get(f"/catalog?{bad}")[0], 400, bad)
        finally:
            self.pg.sql("delete from wallpapers where category = 'zz-pages'")

    def test_hostile_ids_never_reach_the_sql(self):
        for hostile in ("pub1'--", "x'%20or%20'1'='1", "%27%3B%20drop%20table%20wallpapers%3B--"):
            self.assertIn(self.get(f"/file/{hostile}")[0], (400, 404), hostile)
        # The ids that do reach SQL go as a psql variable: quotes inside are just text.
        self.assertEqual(catalog_service.query("select :'id'", {"id": "it's; drop table wallpapers; --"}),
                         "it's; drop table wallpapers; --")
        self.assertEqual(self.pg.sql("select count(*) from wallpapers where id = 'pub1'"), "1")

    def test_rows_without_a_file_are_left_out_before_paging(self):
        """Pages are full and the total counts only what can be fetched."""
        for index in range(6):
            item_id = f"gap{index}"
            self.pg.sql(f"insert into wallpapers (id, title, kind, category, status, playback_key) values "
                        f"('{item_id}', 'g{index}', 'video', 'zz-gaps', 'published', 'live/{item_id}.mp4')")
            if index % 2 == 0:  # only half have a file on this server
                with open(os.path.join(self.storage, f"live/{item_id}.mp4"), "wb") as handle:
                    handle.write(b"x")
        try:
            status, headers, body = self.get("/catalog?limit=2&offset=0")
            self.assertEqual((status, headers["X-Total-Count"], len(json.loads(body))), (200, "4", 2))
            self.assertEqual(headers["X-Next-Offset"], "2")
            _, headers, body = self.get("/catalog?limit=2&offset=2")
            self.assertEqual(len(json.loads(body)), 2)
            self.assertNotIn("X-Next-Offset", headers)
        finally:
            self.pg.sql("delete from wallpapers where category = 'zz-gaps'")

    def test_the_list_is_cached_until_it_changes(self):
        first = json.loads(self.get("/catalog")[2])
        self.pg.sql("update wallpapers set title = 'renamed' where id = 'pub1'")
        try:
            self.assertEqual(json.loads(self.get("/catalog")[2]), first, "read again within the cache time")
            # sync_catalog.py touches the marker when it writes: the next request reads afresh.
            marker = catalog_service.changed_marker()
            self.assertTrue(marker.startswith(self.storage))
            os.makedirs(os.path.dirname(marker), exist_ok=True)
            with open(marker, "a"):
                pass
            os.utime(marker, (time.time() + 5, time.time() + 5))
            self.assertEqual(json.loads(self.get("/catalog")[2])[0]["title"], "renamed")
        finally:
            self.pg.sql("update wallpapers set title = 'pub1' where id = 'pub1'")

    def test_more_requests_than_it_serves_at_once_are_told_to_come_back(self):
        full = catalog_service.Handler.slots
        catalog_service.Handler.slots = threading.BoundedSemaphore(1)
        catalog_service.Handler.slots.acquire()  # the one place is taken
        try:
            status, headers, _ = self.get("/catalog")
            self.assertEqual((status, headers.get("Retry-After")), (503, "1"))
            catalog_service.Handler.slots.release()
            self.assertEqual(self.get("/catalog")[0], 200)
            self.assertEqual(self.get("/catalog")[0], 200)  # and the place is given back each time
        finally:
            catalog_service.Handler.slots = full

    def test_an_unreachable_database_is_a_503_not_a_crash(self):
        good = catalog_service.DATABASE_URL
        catalog_service.DATABASE_URL = f"postgres://allset@127.0.0.1:{pgtest.free_port()}/postgres"
        try:
            self.assertEqual(self.get("/catalog")[0], 503)
        finally:
            catalog_service.DATABASE_URL = good
        self.assertEqual(self.get("/catalog")[0], 200)


    def post(self, path, body, token=None):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        connection.request("POST", path, body=json.dumps(body), headers=headers)
        response = connection.getresponse()
        result = (response.status, json.loads(response.read() or b"{}"))
        connection.close()
        return result

    def test_signing_in_is_required_and_a_password_change_comes_first(self):
        self.assertEqual(self.get("/catalog", token="not-a-session")[0], 401)
        self.assertEqual(self.get("/catalog", token="")[0], 401)

        password = self.accounts.invite("signin@example.com")
        status, body = self.post("/login", {"email": "signin@example.com", "password": password})
        self.assertEqual((status, body["must_change"]), (200, True))
        new_session = body["token"]
        self.assertEqual(self.get("/catalog", token=new_session)[0], 403)
        self.assertEqual(self.get("/file/pub1", token=new_session)[0], 403)
        self.assertEqual(self.get("/me", token=new_session)[0], 403)

        status, body = self.post("/password", {"password": "short"}, token=new_session)
        self.assertEqual(status, 400)
        status, body = self.post("/password", {"password": "a-brand-new-password"}, token=new_session)
        self.assertEqual(status, 200)
        fresh = body["token"]
        self.assertEqual(self.get("/catalog", token=new_session)[0], 401)  # the old session ended
        self.assertEqual(self.get("/catalog", token=fresh)[0], 200)
        self.assertEqual(self.get("/me", token=fresh)[0], 200)
        self.assertEqual(self.post("/logout", {}, token=fresh)[0], 200)
        self.assertEqual(self.get("/catalog", token=fresh)[0], 401)

        self.assertEqual(self.post("/login", {"email": "signin@example.com", "password": "a-brand-new-password"})[0], 200)
        self.assertEqual(self.post("/login", {"email": "signin@example.com", "password": "wrong-password-here"})[0], 401)
        self.assertEqual(self.post("/login", {"email": "nobody@example.com", "password": "x"})[0], 401)
        self.assertEqual(self.post("/login", "not an object")[0], 400)

    def test_too_many_wrong_passwords_are_refused_for_a_while(self):
        catalog_service.Handler.failures.clear()
        for _ in range(catalog_service.LOGIN_LIMIT):
            self.assertEqual(self.post("/login", {"email": "slow@example.com", "password": "nope"})[0], 401)
        self.assertEqual(self.post("/login", {"email": "slow@example.com", "password": "nope"})[0], 429)
        catalog_service.Handler.failures.clear()

    def test_a_disabled_account_loses_access_at_once(self):
        self.accounts.invite("gone@example.com")
        password = self.accounts.reset("gone@example.com")
        session, _ = self.accounts.sign_in("gone@example.com", password)
        session = self.accounts.change_password(session, "a-long-enough-password")
        self.assertEqual(self.get("/catalog", token=session)[0], 200)
        self.accounts.set_disabled("gone@example.com", True)
        self.assertEqual(self.get("/catalog", token=session)[0], 401)
        self.assertIsNone(self.accounts.sign_in("gone@example.com", "a-long-enough-password"))

if __name__ == "__main__":
    unittest.main()
