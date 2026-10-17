"""Builds the public folder: the wallpapers anyone may download, and the list of them.

    /usr/bin/python3 scripts/cloud/publish_catalog.py             # publish
    /usr/bin/python3 scripts/cloud/publish_catalog.py --dry-run   # say what would change, change nothing

Reads the database and the private storage folder, and writes only into the
public folder, which is the one folder a public web server serves:

    public/catalog.json           the list, shaped like the app's own catalog.json
                                  (WallpaperLibraryCatalog), as GET /library is
    public/live/<id>.mp4 ...      each listed file, at the same relative path it
                                  has in storage, so the app asks for it by that path

What goes out, and nothing else:

  - Only rows with status `published`. There is no flag to add quarantined ones:
    this folder is open to the internet, with no key.
  - Only rows whose provenance records a license. A row marked published with no
    license is left out and reported; fix the row, don't publish around it.
  - Only rows whose playback or still file is in storage.
  - Of each row: what the app shows and plays, the author and license, and a
    SHA-256 of each file. Never origin_root, origin_file or a Workshop id.

Order matters to someone downloading meanwhile: files first, then catalog.json
(replaced in one step), then the files no longer listed are removed. So the list
never names a file that isn't there. Taking a wallpaper down is: unpublish or
delete its row, then run this.

catalog.json is written only when the list changed, and `revision` goes up by
one each time it does, so an unchanged library keeps the same file and ETag.

A file is hard-linked into the public folder (copied when that isn't possible),
so publishing takes no extra disk space. Run on the server, where the database
is local; --url, --storage and --public say where else (scripts/cloud/server.sh).

Tests: /usr/bin/python3 -m unittest scripts/cloud/test_publish_catalog.py
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys

STORAGE = os.path.expanduser("~/AllSetStorage/wallpapers")
PUBLIC = os.path.expanduser("~/AllSetStorage/public")
DATABASE_URL = "postgres://allset@localhost/allset"
PSQL = "/opt/homebrew/bin/psql" if os.path.exists("/opt/homebrew/bin/psql") else "psql"
DATABASE_TIMEOUT = 60
CATALOG = "catalog.json"
# The one library folder a receiving Mac's catalog names (LibrarySync.root).
LIBRARY_ROOT = "server"
# A file being put in place; never listed, and swept up if a run was interrupted.
PARTIAL = ".publishing"
ROLES = (("playback", "playback_key"), ("still", "still_key"), ("thumbnail", "thumbnail_key"))


class PublishError(Exception):
    pass


def fetch_rows(url, psql=None):
    """Every published row, in the order the catalog lists them."""
    sql = ("select coalesce(json_agg(t), '[]') from (select id, title, kind, category, tags, playback_key, "
           "still_key, thumbnail_key, duration, width, height, fps, provenance, content_rating, added_at "
           "from wallpapers where status = 'published' order by category, title, id) t")
    try:
        result = subprocess.run([psql or PSQL, url, "-At", "-v", "ON_ERROR_STOP=1", "-c", sql],
                                capture_output=True, text=True, timeout=DATABASE_TIMEOUT)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise PublishError(str(error))
    if result.returncode != 0:
        raise PublishError(result.stderr.strip() or f"psql exited {result.returncode}")
    return json.loads(result.stdout.strip() or "[]")


def contained(root, key):
    """The file `key` names inside `root`, or None: when it isn't there, or the
    key is anything but a plain relative path (absolute, `..`, or into a dot
    folder such as storage's .retired and .trash)."""
    if not key or os.path.isabs(key) or any(part in ("", "..") or part.startswith(".") for part in key.split("/")):
        return None
    path = os.path.realpath(os.path.join(root, key))
    if not path.startswith(os.path.realpath(root) + os.sep) or not os.path.isfile(path):
        return None
    return path


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def license_of(row):
    provenance = row.get("provenance")
    value = provenance.get("license") if isinstance(provenance, dict) else None
    return value.strip() if isinstance(value, str) else ""


def entry(row, storage):
    """(catalog item, {relative path: file in storage}) for a row that may go
    out, or (None, why not)."""
    if not license_of(row):
        return None, "no license recorded"
    files = {role: (row.get(column), contained(storage, row.get(column))) for role, column in ROLES}
    found = {role: key for role, (key, path) in files.items() if path}
    if "playback" not in found and "still" not in found:
        return None, "its file isn't in storage"
    main = "playback" if "playback" in found else "still"
    provenance = {"license": license_of(row)}
    author = row["provenance"].get("author")
    if isinstance(author, str) and author.strip():
        provenance["author"] = author.strip()
    item = {"id": row["id"], "title": row["title"], "kind": row["kind"], "category": row["category"],
            "tags": row.get("tags") or [], "root": LIBRARY_ROOT, "file": found[main],
            "thumbnail": found.get("thumbnail"), "playback": found.get("playback"), "still": found.get("still"),
            "duration": row.get("duration"), "width": row.get("width"), "height": row.get("height"),
            "fps": row.get("fps"), "size": os.path.getsize(files[main][1]), "status": "published",
            "provenance": provenance, "contentRating": row.get("content_rating"), "addedAt": row.get("added_at"),
            "checksums": {role: sha256(files[role][1]) for role in found}}
    return ({name: value for name, value in item.items() if value is not None},
            {key: files[role][1] for role, key in found.items()})


def in_place(source, destination, checksum):
    """Whether `destination` already is `source`'s content."""
    if not os.path.isfile(destination) or os.path.islink(destination):
        return False
    if os.path.samefile(source, destination):
        return True
    return os.path.getsize(source) == os.path.getsize(destination) and sha256(destination) == checksum


def place(source, destination):
    """Puts `source` at `destination` in one step: whoever asks for it gets the
    old file or the whole new one."""
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    partial = destination + PARTIAL
    if os.path.lexists(partial):
        os.remove(partial)
    try:
        os.link(source, partial)
    except OSError:
        shutil.copy2(source, partial)
    os.replace(partial, destination)


def previous(public):
    """(revision, items) of the catalog published now; (0, None) when there is none."""
    try:
        with open(os.path.join(public, CATALOG)) as handle:
            catalog = json.load(handle)
        return int(catalog.get("revision", 0)), catalog.get("items")
    except (OSError, ValueError, AttributeError, TypeError):
        return 0, None


def check_folders(storage, public):
    """Refuses a public folder this could damage or that would expose storage."""
    if not os.path.isdir(storage):
        raise PublishError(f"{storage} isn't a folder")
    real_storage, real_public = os.path.realpath(storage), os.path.realpath(public)
    if os.path.commonpath([real_storage, real_public]) in (real_storage, real_public):
        raise PublishError("the public folder and the storage folder must be separate, neither inside the other")
    # Publishing removes what the catalog doesn't list: only from a folder that is
    # empty or that an earlier run made.
    if os.path.isdir(public) and os.listdir(public) and not os.path.isfile(os.path.join(public, CATALOG)):
        raise PublishError(f"{public} holds files but no {CATALOG}: not a published folder, so nothing in it is touched")


def unlisted(public, listed):
    """Files in the public folder the catalog doesn't name, as relative paths."""
    extra = []
    for folder, _, names in os.walk(public):
        for name in names:
            relative = os.path.relpath(os.path.join(folder, name), public)
            if relative != CATALOG and relative not in listed:
                extra.append(relative)
    return sorted(extra)


def publish(rows, storage, public, dry_run=False):
    """Makes the public folder match `rows`. Returns what it did:
    {"items", "revision", "changed", "added", "removed", "skipped": [(id, title, why)]}."""
    check_folders(storage, public)
    items, wanted, skipped = [], {}, []
    for row in rows:
        item, result = entry(row, storage)
        if item is None:
            skipped.append((row["id"], row["title"], result))
            continue
        items.append(item)
        wanted.update(result)

    checksums = {item[role]: item["checksums"][role] for item in items for role in item["checksums"]}
    added = [relative for relative, source in sorted(wanted.items())
             if not in_place(source, os.path.join(public, relative), checksums[relative])]
    revision, published = previous(public)
    changed = items != published
    if changed:
        revision += 1
    removed = unlisted(public, wanted) if os.path.isdir(public) else []
    report = {"items": len(items), "revision": revision, "changed": changed, "added": added,
              "removed": removed, "skipped": skipped}
    if dry_run:
        return report

    os.makedirs(public, exist_ok=True)
    for relative in added:
        place(wanted[relative], os.path.join(public, relative))
    if changed:
        partial = os.path.join(public, CATALOG + PARTIAL)
        with open(partial, "w") as handle:
            json.dump({"version": 1, "revision": revision, "roots": [], "items": items}, handle,
                      sort_keys=True, separators=(",", ":"))
        os.replace(partial, os.path.join(public, CATALOG))
    for relative in removed:
        os.remove(os.path.join(public, relative))
    for folder, _, _ in os.walk(public, topdown=False):
        if folder != public and not os.listdir(folder):
            os.rmdir(folder)
    return report


def describe(report, dry_run):
    would = "would be " if dry_run else ""
    lines = [f"{report['items']} wallpapers {would}public, catalog revision {report['revision']}"
             + ("" if report["changed"] else " (unchanged)"),
             f"{len(report['added'])} files {would}added, {len(report['removed'])} {would}removed"]
    if report["skipped"]:
        lines.append(f"{len(report['skipped'])} published rows left out:")
        lines += [f"  {id}  {title}: {why}" for id, title, why in report["skipped"]]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="say what would change; change nothing")
    parser.add_argument("--url", default=os.environ.get("DATABASE_URL", DATABASE_URL), help="database to read")
    parser.add_argument("--storage", default=STORAGE, help="the private wallpaper folder")
    parser.add_argument("--public", default=PUBLIC, help="the folder the public web server serves")
    args = parser.parse_args()
    try:
        report = publish(fetch_rows(args.url), args.storage, args.public, args.dry_run)
    except PublishError as error:
        sys.exit(f"Nothing published: {error}")
    print(describe(report, args.dry_run))


if __name__ == "__main__":
    main()
