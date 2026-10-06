"""The importer's catalog and cleanup safety, with throwaway folders only.

    /usr/bin/python3 -m unittest scripts/test_wallpaper_library.py
"""
import json
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import wallpaper_library as importer  # noqa: E402


def tex(container, image, compressed=None, width=2, height=2, fmt=0):
    """A minimal Wallpaper Engine texture: one image, one mipmap."""
    import struct
    data = b"TEXV0005\0" + b"TEXI0001\0" + struct.pack("<7i", fmt, 0, width, height, width, height, 0)
    data += container + b"\0" + struct.pack("<i", 1)
    if container in (b"TEXB0003", b"TEXB0004"):
        data += struct.pack("<i", -1)
    if container == b"TEXB0004":
        data += struct.pack("<i", 0)
    data += struct.pack("<iii", 1, width, height)
    if container != b"TEXB0001":
        data += struct.pack("<ii", 1 if compressed else 0, compressed or 0)
    return data + struct.pack("<i", len(image)) + image


class HostileInputTests(unittest.TestCase):
    """Review O6: archive offsets, loose paths, LZ4 and texture sizes were
    trusted, and tools ran with no deadline."""

    @classmethod
    def setUpClass(cls):
        cls.work = tempfile.mkdtemp(prefix="allset-hostile-")
        cls.wetex = os.path.join(cls.work, "wetex")
        import subprocess
        subprocess.run(["xcrun", "swiftc", "-O", os.path.join(HERE, "wetex.swift"), "-o", cls.wetex], check=True,
                       capture_output=True)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.work, ignore_errors=True)

    def pkg(self, entries, body=b"", count=None, name_length=None):
        import struct
        data = struct.pack("<i", 8) + b"PKGV0001" + struct.pack("<i", len(entries) if count is None else count)
        for name, offset, length in entries:
            encoded = name.encode()
            data += struct.pack("<i", len(encoded) if name_length is None else name_length) + encoded
            data += struct.pack("<ii", offset, length)
        folder = tempfile.mkdtemp(dir=self.work)
        with open(os.path.join(folder, "scene.pkg"), "wb") as handle:
            handle.write(data + body)
        return folder

    def test_a_good_package_reads(self):
        folder = self.pkg([("scene.json", 0, 2)], body=b"{}")
        self.assertEqual(importer.Package(folder, "scene.pkg").json("scene.json"), {})

    def test_entries_outside_the_file_are_refused(self):
        folder = self.pkg([("scene.json", 0, 1_000_000)], body=b"{}")
        with self.assertRaises(importer.PackageError):
            importer.Package(folder, "scene.pkg")
        folder = self.pkg([("scene.json", -5, 2)], body=b"{}")
        with self.assertRaises(importer.PackageError):
            importer.Package(folder, "scene.pkg")

    def test_truncated_and_absurd_headers_are_refused(self):
        folder = self.pkg([("scene.json", 0, 2)], count=2_000_000_000)
        with self.assertRaises(importer.PackageError):
            importer.Package(folder, "scene.pkg")
        folder = self.pkg([("scene.json", 0, 2)], name_length=1 << 30)
        with self.assertRaises(importer.PackageError):
            importer.Package(folder, "scene.pkg")
        folder = tempfile.mkdtemp(dir=self.work)
        with open(os.path.join(folder, "scene.pkg"), "wb") as handle:
            handle.write(b"\x08\x00")
        with self.assertRaises(importer.PackageError):
            importer.Package(folder, "scene.pkg")

    def test_loose_files_stay_inside_the_scene_folder(self):
        folder = tempfile.mkdtemp(dir=self.work)
        with open(os.path.join(self.work, "secret.txt"), "w") as handle:
            handle.write("not the scene's")
        package = importer.Package(folder, "scene.pkg")
        self.assertFalse(package.has("../secret.txt"))
        self.assertFalse(package.has(os.path.join(self.work, "secret.txt")))
        with self.assertRaises(KeyError):
            package.read("../secret.txt")
        self.assertIsNone(package.json("../secret.txt"))

    def run_wetex(self, data):
        import subprocess
        source = os.path.join(self.work, "in.tex")
        with open(source, "wb") as handle:
            handle.write(data)
        result = subprocess.run([self.wetex, source, os.path.join(self.work, "out")], capture_output=True, text=True, timeout=30)
        return result.returncode, json.loads(result.stdout.strip().splitlines()[-1])

    def test_wetex_decodes_a_good_texture(self):
        code, info = self.run_wetex(tex(b"TEXB0001", bytes(range(16))))
        self.assertEqual((code, info.get("kind"), info.get("width")), (0, "image", 2))

    def test_wetex_reports_a_truncated_file_instead_of_crashing(self):
        code, info = self.run_wetex(tex(b"TEXB0001", bytes(range(16)))[:40])
        self.assertEqual(code, 1)
        self.assertIn("truncated", info["error"])

    def test_wetex_reports_a_cut_off_lz4_match(self):
        # One literal, then a match whose two-byte offset has only one byte.
        code, info = self.run_wetex(tex(b"TEXB0002", bytes([0x10, 0x41, 0x05]), compressed=16))
        self.assertEqual(code, 1)
        self.assertIn("LZ4", info["error"])

    def test_wetex_refuses_absurd_sizes(self):
        code, info = self.run_wetex(tex(b"TEXB0001", b"", width=1 << 20, height=1 << 20))
        self.assertEqual(code, 1)
        self.assertIn("implausible", info["error"])

    def test_a_tool_past_its_deadline_is_stopped(self):
        import time
        start = time.monotonic()
        result = importer.run_tool(["/bin/sleep", "5"], timeout=0.3, capture_output=True, text=True)
        self.assertLess(time.monotonic() - start, 3)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("timed out", result.stderr)

    def test_json_writes_leave_no_shared_temporary(self):
        path = os.path.join(self.work, "catalog.json")
        importer.write_json_atomic(path, {"items": []})
        importer.write_json_atomic(path, {"items": [1]})
        with open(path) as handle:
            self.assertEqual(json.load(handle), {"items": [1]})
        self.assertEqual([n for n in os.listdir(self.work) if n.startswith("catalog.json.")], [])

    def test_two_imports_cant_change_one_library_at_once(self):
        library = tempfile.mkdtemp(dir=self.work)
        with importer.library_lock(library):
            with self.assertRaises(importer.LibraryBusy):
                with importer.library_lock(library):
                    pass
        with importer.library_lock(library):
            pass


class CatalogSafetyTests(unittest.TestCase):
    def setUp(self):
        self.library = tempfile.mkdtemp(prefix="allset-import-test-")
        self.root = tempfile.mkdtemp(prefix="allset-import-root-")

    def tearDown(self):
        shutil.rmtree(self.library, ignore_errors=True)
        shutil.rmtree(self.root, ignore_errors=True)

    def asset(self, relative, content="x"):
        path = os.path.join(self.library, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as handle:
            handle.write(content)
        return path

    def exists(self, relative):
        return os.path.exists(os.path.join(self.library, relative))

    def test_a_missing_catalog_is_a_fresh_library(self):
        self.assertEqual(importer.load_catalog(self.library)["items"], [])

    def test_an_unreadable_catalog_is_kept_and_stops_the_import(self):
        """Review R9: it was treated as empty, then cleanup deleted another root's files."""
        with open(os.path.join(self.library, "catalog.json"), "w") as handle:
            handle.write("{ damaged")
        self.asset("live/otherroot.mp4", "someone else's")
        original_inventory = importer.inventory
        importer.inventory = lambda root, library: {"root": self.root, "files": []}
        try:
            with self.assertRaises(importer.CatalogUnreadable):
                importer.import_library(self.root, self.library, live=False)
        finally:
            importer.inventory = original_inventory
        self.assertTrue(self.exists("live/otherroot.mp4"))
        with open(os.path.join(self.library, "catalog.json")) as handle:
            self.assertEqual(handle.read(), "{ damaged")
        copies = [n for n in os.listdir(self.library) if n.startswith("catalog.unreadable-")]
        self.assertEqual(len(copies), 1)

    def test_a_catalog_of_the_wrong_shape_counts_as_unreadable(self):
        with open(os.path.join(self.library, "catalog.json"), "w") as handle:
            json.dump([1, 2], handle)
        with self.assertRaises(importer.CatalogUnreadable):
            importer.load_catalog(self.library)

    def test_orphans_are_moved_aside_not_deleted(self):
        self.asset("live/used.mp4")
        self.asset("live/orphan.mp4", "keep me recoverable")
        importer.clean_orphans(self.library, {"items": [{"id": "used", "playback": "live/used.mp4"}]})
        self.assertTrue(self.exists("live/used.mp4"))
        self.assertFalse(self.exists("live/orphan.mp4"))
        held = [os.path.join(base, name) for base, _, names in os.walk(os.path.join(self.library, ".orphans")) for name in names]
        self.assertEqual(len(held), 1)
        with open(held[0]) as handle:
            self.assertEqual(handle.read(), "keep me recoverable")

    def test_an_empty_catalog_never_clears_the_library(self):
        self.asset("live/a.mp4")
        self.asset("thumbnails/a.jpg")
        importer.clean_orphans(self.library, {"items": []})
        self.assertTrue(self.exists("live/a.mp4"))
        self.assertTrue(self.exists("thumbnails/a.jpg"))

    def test_only_the_latest_few_cleanups_are_kept(self):
        for run in range(5):
            self.asset(f"live/orphan{run}.mp4")
            self.asset("live/used.mp4")
            importer.clean_orphans(self.library, {"items": [{"playback": "live/used.mp4"}]}, stamp=f"2026100{run}-000000")
        runs = sorted(os.listdir(os.path.join(self.library, ".orphans")))
        self.assertEqual(runs, ["20261002-000000", "20261003-000000", "20261004-000000"])


if __name__ == "__main__":
    unittest.main()
