"""Loads a wallpaper library's files into the server's storage folder and points
each row at its files, on one Mac: no tunnel, no Tailscale, no rsync over SSH.

    /usr/bin/python3 scripts/cloud/load_library.py --url URL --storage FOLDER [--library FOLDER] [--dry-run]
    scripts/cloud/server.sh load [library folder]     # sync_catalog.py, then this

`--library` is a library folder as the app keeps it (catalog.json, live/,
stills/, thumbnails/ ...): by default this Mac's own, or a copy of one brought
over on a disk. The rows must be in the database already (sync_catalog.py).

For every wallpaper in the catalog it copies the playback file, the still and
the thumbnail that are in the library folder to the same relative path in
storage, then sets playback_key, still_key and thumbnail_key for the files that
are now there. A file already in storage with the same size is left alone, so
it can be run again. Nothing is ever deleted, and a key is never cleared: a
file this library doesn't have (freed from this Mac, say) keeps the key it had.

It is what push_wallpapers.sh and set_storage_key.py do between two Macs, for
the case where the library and the server are on the same one. Keys are set in
one transaction under the catalog lock (catalog_lock.py), after the files are
in their places.

Loading changes nothing about who may see a wallpaper: that is its row's
status, and only publish_catalog.py puts anything in the public folder.

Tests: /usr/bin/python3 -m unittest scripts/cloud/test_load_library.py
"""
import argparse
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import catalog_lock  # noqa: E402
from publish_catalog import contained  # noqa: E402

LIBRARY = os.path.expanduser("~/Library/Application Support/AllSet/Wallpaper/Library")
PSQL = "/opt/homebrew/bin/psql" if os.path.exists("/opt/homebrew/bin/psql") else "psql"
# Catalog field -> the row's column.
KEYS = (("playback", "playback_key"), ("still", "still_key"), ("thumbnail", "thumbnail_key"))
PARTIAL = ".loading"


class LoadError(Exception):
    pass


def copy(source, destination):
    """Puts a copy at `destination` in one step. On the same APFS disk the copy
    is a clone: it takes no space until one of the two changes."""
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    partial = destination + PARTIAL
    if os.path.lexists(partial):
        os.remove(partial)
    cloned = subprocess.run(["/bin/cp", "-c", source, partial], capture_output=True)
    if cloned.returncode != 0:
        shutil.copyfile(source, partial)
    os.replace(partial, destination)


def quoted(value):
    return "null" if value is None else "'" + value.replace("'", "''") + "'"


def load(items, library, storage, dry_run=False):
    """Copies what `items` name from `library` into `storage`. Returns
    (report, keys): keys is {id: {column: relative path}} for every file that is
    in storage afterwards (in a dry run: that would be)."""
    if not os.path.isdir(storage):
        raise LoadError(f"{storage} isn't a folder")
    real_library, real_storage = os.path.realpath(library), os.path.realpath(storage)
    if os.path.commonpath([real_library, real_storage]) in (real_library, real_storage):
        raise LoadError("the library folder and the storage folder must be separate, neither inside the other")
    report = {"copied": 0, "already": 0, "missing": 0, "bytes": 0}
    keys, seen = {}, set()
    for item in items:
        if item.get("status") == "unsupported" or not isinstance(item.get("id"), str):
            continue
        for field, column in KEYS:
            relative = item.get(field)
            if not relative:
                continue
            destination = os.path.join(storage, relative)
            source = contained(library, relative)
            in_storage = contained(storage, relative) is not None
            if source and relative not in seen:
                seen.add(relative)
                if in_storage and os.path.getsize(destination) == os.path.getsize(source):
                    report["already"] += 1
                else:
                    report["copied"] += 1
                    report["bytes"] += os.path.getsize(source)
                    if not dry_run:
                        copy(source, destination)
                    in_storage = True
            elif not source and not in_storage:
                report["missing"] += 1
            if in_storage:
                keys.setdefault(item["id"], {})[column] = relative
    return report, keys


def set_keys(url, keys, psql=None):
    """Points the rows at their files, and returns how many rows there were to
    point. A key this run has no file for stays as it was."""
    if not keys:
        return 0
    columns = [column for _, column in KEYS]
    values = ",\n".join("(" + ", ".join([quoted(id)] + [quoted(found.get(column)) for column in columns]) + ")"
                        for id, found in sorted(keys.items()))
    script = (f"begin;\nselect pg_advisory_xact_lock({catalog_lock.ASSET_LOCK});\n"
              "with loaded (id, playback_key, still_key, thumbnail_key) as (values\n" + values + "\n), changed as (\n"
              "update wallpapers w set " + ", ".join(f"{c} = coalesce(loaded.{c}, w.{c})" for c in columns) +
              ", uploaded_at = now() from loaded where w.id = loaded.id returning 1)\n"
              "select count(*) from changed;\ncommit;\n")
    result = subprocess.run([psql or PSQL, url, "-q", "-At", "-v", "ON_ERROR_STOP=1", "-f", "-"],
                            input=script, capture_output=True, text=True)
    if result.returncode != 0:
        raise LoadError(result.stderr.strip() or f"psql exited {result.returncode}")
    return int(result.stdout.split()[-1])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--url", required=True, help="the server's database")
    parser.add_argument("--storage", required=True, help="the server's storage/wallpapers folder")
    parser.add_argument("--library", default=LIBRARY, help="the library folder to load from (default: this Mac's)")
    parser.add_argument("--dry-run", action="store_true", help="say what would be copied; change nothing")
    args = parser.parse_args()
    try:
        with open(os.path.join(args.library, "catalog.json")) as handle:
            items = json.load(handle)["items"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        sys.exit(f"No readable catalog.json in {args.library}: {error}")
    try:
        report, keys = load(items, args.library, args.storage, args.dry_run)
        rows = len(keys) if args.dry_run else set_keys(args.url, keys)
    except LoadError as error:
        sys.exit(f"Not loaded: {error}")
    would = "would be " if args.dry_run else ""
    print(f"{report['copied']} files {would}copied ({report['bytes'] / 1e9:.2f} GB), {report['already']} already in storage")
    print(f"{report['missing']} files the catalog names are in neither folder (freed from this Mac, or never made)")
    print(f"{rows} wallpapers {would}pointed at their files" +
          ("" if args.dry_run or rows == len(keys) else f" ({len(keys) - rows} have no row: run sync_catalog.py first)"))


if __name__ == "__main__":
    main()
