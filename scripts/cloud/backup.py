"""Backs up the wallpaper server, and proves a backup can be restored.

    /usr/bin/python3 scripts/cloud/backup.py backup  <destination folder> [--keep 7] [--drill]
    /usr/bin/python3 scripts/cloud/backup.py drill   <backup folder>
    /usr/bin/python3 scripts/cloud/backup.py restore <backup folder> --database-url URL --storage FOLDER

Run on the server. `<destination folder>` should be on another disk.

backup   Writes <destination>/<UTC time>/ with the database (allset.sql, from
         pg_dump), a copy of the storage folder (files/) and manifest.json: the
         row count and each file's size and SHA-256. Files unchanged since the
         last backup are hard links to it, so a night with no changes costs
         almost no space. Before removing older backups under --keep, the new
         backup must pass a restore drill. A failed drill preserves older copies.
         Nothing on the live server is changed.

drill    The rehearsal. Restores the backup into a scratch database and a
         scratch folder, then checks it: the dump loads, the row count matches
         the manifest, every file matches its SHA-256, and every file a row
         points at is there. Removes the scratch copies and says what it found.
         Exits 0 only if everything matched. Run it after a backup, and from
         time to time: a backup nobody has restored is a hope, not a backup.

restore  The real thing, by the same code the drill runs. Only into a database
         with no wallpapers and an empty (or missing) folder: it never
         overwrites. To replace a damaged server: stop the services, move the
         damaged database and folder aside, restore, then start the services.

What is not in a backup: a delete still in progress (.trash). Retired files
(.retired) are included, so a restore keeps their week of grace.

The database and the files are copied one after the other, not at one
instant. A wallpaper deleted in between can leave a backup whose rows and
files disagree; the drill reports exactly that, and the next backup is whole.

Tests: /usr/bin/python3 -m unittest scripts/cloud/test_backup.py
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse

BIN = "/opt/homebrew/bin"
PSQL = f"{BIN}/psql" if os.path.exists(f"{BIN}/psql") else "psql"
PG_DUMP = f"{BIN}/pg_dump" if os.path.exists(f"{BIN}/pg_dump") else "pg_dump"
RSYNC = "/usr/bin/rsync"
STORAGE = os.path.expanduser("~/AllSetStorage/wallpapers")
DATABASE_URL = "postgres://allset@localhost/allset"
KEY_COLUMNS = ("playback_key", "still_key", "thumbnail_key")
STAMP = re.compile(r"^\d{8}T\d{6}Z$")
TIMEOUT = 6 * 3600  # seconds for one dump, copy or load


class BackupError(Exception):
    pass


def run(command, accept=(0,)):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=TIMEOUT)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise BackupError(f"{os.path.basename(command[0])}: {error}")
    if result.returncode not in accept:
        raise BackupError(f"{os.path.basename(command[0])} failed: {result.stderr.strip()[:500]}")
    return result.stdout


def query(url, statement):
    return run([PSQL, url, "-q", "-At", "-v", "ON_ERROR_STOP=1", "-c", statement]).strip()


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def files_under(root):
    """Relative paths of every file under root, sorted."""
    return sorted(os.path.relpath(os.path.join(base, name), root)
                  for base, _, names in os.walk(root) for name in names)


def backups_in(destination):
    """Finished backups in a destination folder, oldest first."""
    if not os.path.isdir(destination):
        return []
    return sorted(os.path.join(destination, name) for name in os.listdir(destination)
                  if STAMP.match(name) and os.path.isfile(os.path.join(destination, name, "manifest.json")))


def read_manifest(backup_folder):
    try:
        with open(os.path.join(backup_folder, "manifest.json")) as handle:
            manifest = json.load(handle)
    except (OSError, ValueError) as error:
        raise BackupError(f"{backup_folder} has no readable manifest: {error}")
    if not isinstance(manifest.get("files"), dict) or not isinstance(manifest.get("rows"), int):
        raise BackupError(f"{backup_folder}: the manifest isn't in the expected shape")
    return manifest


def backup(destination, keep=7, now=None):
    """Makes a backup and returns its folder. Raises BackupError and leaves no
    half-made backup behind if any step fails."""
    stamp = (now or datetime.datetime.now(datetime.timezone.utc)).strftime("%Y%m%dT%H%M%SZ")
    os.makedirs(destination, exist_ok=True)
    final = os.path.join(destination, stamp)
    if os.path.exists(final):
        raise BackupError(f"{final} already exists")
    earlier = backups_in(destination)
    previous = earlier[-1] if earlier else None
    working = tempfile.mkdtemp(prefix=f".{stamp}-", dir=destination)
    try:
        with open(os.path.join(working, "allset.sql"), "w") as dump:
            try:
                made = subprocess.run([PG_DUMP, "--no-owner", "--no-privileges", DATABASE_URL], stdout=dump,
                                      stderr=subprocess.PIPE, text=True, timeout=TIMEOUT)
            except (OSError, subprocess.TimeoutExpired) as error:
                raise BackupError(f"pg_dump: {error}")
        if made.returncode != 0:
            raise BackupError(f"pg_dump failed: {made.stderr.strip()[:500]}")
        rows = int(query(DATABASE_URL, "select count(*) from wallpapers"))

        files = os.path.join(working, "files")
        os.makedirs(files)
        if os.path.isdir(STORAGE):
            link = [f"--link-dest={os.path.join(os.path.abspath(previous), 'files')}"] if previous else []
            # 24: a file went away while copying (a purge of retired files ran). The
            # manifest below lists what was copied, so the backup still agrees with itself.
            run([RSYNC, "-a", "--exclude=/.trash/"] + link + [STORAGE.rstrip("/") + "/", files + "/"], accept=(0, 24))

        known = read_manifest(previous)["files"] if previous else {}
        listed = {}
        for relative in files_under(files):
            path = os.path.join(files, relative)
            status = os.stat(path)
            before = known.get(relative)
            # Unchanged since the last backup (rsync linked it): its checksum stands.
            same = before and before.get("size") == status.st_size and before.get("mtime") == int(status.st_mtime)
            listed[relative] = {"size": status.st_size, "mtime": int(status.st_mtime),
                                "sha256": before["sha256"] if same else sha256(path)}
        with open(os.path.join(working, "manifest.json"), "w") as handle:
            json.dump({"created": stamp, "rows": rows, "files": listed}, handle, indent=1, sort_keys=True)
        os.rename(working, final)
    except BaseException:
        shutil.rmtree(working, ignore_errors=True)
        raise
    # Retention is allowed only after this replacement has passed a restore
    # drill. A failed or unavailable drill leaves every older copy untouched.
    if keep > 0:
        problems, _ = drill(final)
        if problems:
            raise BackupError("New backup failed its restore drill; older backups were kept: " + "; ".join(problems))
        for old in backups_in(destination)[:-keep]:
            shutil.rmtree(old)
    return final


def with_database(url, name):
    """The same server and login as `url`, another database."""
    parts = urllib.parse.urlsplit(url)
    return urllib.parse.urlunsplit(parts._replace(path="/" + name))


def restore(backup_folder, database_url, storage):
    """Loads a backup into `database_url` and `storage`, which must hold
    nothing. Returns the manifest."""
    manifest = read_manifest(backup_folder)
    if os.path.isdir(storage) and os.listdir(storage):
        raise BackupError(f"{storage} isn't empty: a restore never overwrites")
    if query(database_url, "select to_regclass('wallpapers') is not null") == "t":
        raise BackupError("the database already has a wallpapers table: a restore never overwrites")
    run([PSQL, database_url, "-q", "-v", "ON_ERROR_STOP=1", "-f", os.path.join(backup_folder, "allset.sql")])
    os.makedirs(storage, exist_ok=True)
    run([RSYNC, "-a", os.path.join(backup_folder, "files") + "/", storage.rstrip("/") + "/"])
    return manifest


def check(manifest, database_url, storage):
    """What is wrong with a restored copy, as a list (empty when nothing is)."""
    problems = []
    rows = int(query(database_url, "select count(*) from wallpapers"))
    if rows != manifest["rows"]:
        problems.append(f"{rows} wallpapers restored, the backup recorded {manifest['rows']}")
    present = set(files_under(storage))
    for relative, expected in sorted(manifest["files"].items()):
        if relative not in present:
            problems.append(f"missing file: {relative}")
        elif sha256(os.path.join(storage, relative)) != expected["sha256"]:
            problems.append(f"file differs from its checksum: {relative}")
    for extra in sorted(present - set(manifest["files"])):
        problems.append(f"file not in the manifest: {extra}")
    columns = ", ".join(KEY_COLUMNS)
    pointed = query(database_url, f"select distinct k from wallpapers, unnest(array[{columns}]) as k where k is not null")
    for key in sorted(filter(None, pointed.splitlines())):
        if not os.path.isfile(os.path.join(storage, key)):
            problems.append(f"a wallpaper points at a file that isn't there: {key}")
    return problems


def drill(backup_folder):
    """Restores a backup into scratch copies, checks it and removes them.
    Returns (problems, summary)."""
    name = "allset_drill_" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d%H%M%S%f")
    scratch_url = with_database(DATABASE_URL, name)
    scratch_files = tempfile.mkdtemp(prefix="allset-restore-drill-")
    query(DATABASE_URL, f"create database {name}")
    try:
        manifest = restore(backup_folder, scratch_url, os.path.join(scratch_files, "files"))
        problems = check(manifest, scratch_url, os.path.join(scratch_files, "files"))
    finally:
        try:
            query(DATABASE_URL, f"drop database if exists {name} with (force)")
        finally:
            shutil.rmtree(scratch_files, ignore_errors=True)
    return problems, f"{manifest['rows']} wallpapers, {len(manifest['files'])} files"


def main():
    global DATABASE_URL, STORAGE
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["backup", "drill", "restore"])
    parser.add_argument("folder", help="backup: where backups go; drill and restore: one backup's folder")
    parser.add_argument("--keep", type=int, default=7, help="backup: how many to keep (0 keeps all)")
    parser.add_argument("--drill", action="store_true", help="backup: run the restore drill on it straight after")
    parser.add_argument("--database-url", help="the database (default: this server's)")
    parser.add_argument("--storage", help="the storage folder (default: this server's)")
    args = parser.parse_args()
    try:
        if args.command == "restore":
            if not args.database_url or not args.storage:
                sys.exit("restore needs --database-url and --storage: say exactly where it goes.")
            manifest = restore(args.folder, args.database_url, args.storage)
            problems = check(manifest, args.database_url, args.storage)
            print(f"Restored {manifest['rows']} wallpapers and {len(manifest['files'])} files.")
            if problems:
                sys.exit("But it doesn't match the backup:\n  " + "\n  ".join(problems))
            return
        DATABASE_URL = args.database_url or DATABASE_URL
        STORAGE = args.storage or STORAGE
        if args.command == "backup":
            made = backup(args.folder, keep=args.keep)
            manifest = read_manifest(made)
            print(f"Backed up {manifest['rows']} wallpapers and {len(manifest['files'])} files to {made}")
            if args.keep > 0:
                print(f"Restore drill passed for {made}; retention applied only after verification.")
                return
            if not args.drill:
                return
            args.folder = made
        problems, summary = drill(args.folder)
        if problems:
            sys.exit(f"Restore drill FAILED for {args.folder} ({summary}):\n  " + "\n  ".join(problems))
        print(f"Restore drill passed for {args.folder}: {summary} restored and verified.")
    except BackupError as error:
        sys.exit(str(error))


if __name__ == "__main__":
    main()
