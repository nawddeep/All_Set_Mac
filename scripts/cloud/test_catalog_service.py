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
import unittest
from http.server import ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import catalog_service  # noqa: E402
import pgtest  # noqa: E402

TOKEN = "catalog-test-key"


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
        catalog_service.Handler.token = TOKEN
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

    def get(self, path, headers=None, token=TOKEN):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        connection.request("GET", path, headers={"Authorization": f"Bearer {token}", **(headers or {})})
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


if __name__ == "__main__":
    unittest.main()
