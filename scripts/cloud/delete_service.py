"""A tiny, deliberately narrow HTTP service on the home server: the one
place a permanent delete from the app can reach the Postgres row and the
server's copy of a wallpaper's files. Nothing else.

Not exposed on the Tailscale interface directly, unlike Caddy — bound to
localhost only, reached the same way Postgres already is: through the SSH
tunnel (`scripts/cloud/tunnel.sh`, which forwards this port too). So a
delete needs, in order: an SSH key for this Mac, this bearer token, and
(client-side) Touch ID before the app ever sends the request — three
layers, not one.

First run creates a token, stores it at ~/.allset_delete_token (chmod 600,
same pattern as ~/.allset_pg_credentials) and prints it once — put that in
the client Mac's Keychain (see DeleteAPIKeychain.swift), it isn't shown
again.

Not a launchd service yet: start it by hand when you want deletes to work,
same as the tunnel. Can become one later the way Caddy and Postgres did.

What it deletes is decided here, never by the request: a wallpaper's own files
are `<folder>/<id>.<ext>` in the storage folders, plus the storage keys in its
database row that no other row also uses. A `paths` list in the request (sent
by older app versions) is ignored.

A delete is staged so the files and the database can't end up disagreeing:
the files move into STORAGE/.trash/<id>/ first, then the row is deleted, then
the quarantine is emptied. If the database step fails, the files move back and
nothing has changed (503: retry). A quarantine left behind by a crash is
settled at startup: files go back if the row is still there, or are retired if
it's gone.

Two things keep a file that another wallpaper comes to use from being lost:

- The row is deleted and "does another row use these files?" is asked in one
  transaction, under the lock every catalog writer takes (catalog_lock.py). A
  writer that takes the lock either commits first, and its file is kept, or
  waits and then finds the file no longer in place.
- Deleted files are retired, not destroyed: they move to
  STORAGE/.retired/<id>/<time>/ and stay for RETENTION_DAYS. A retired file
  that any row references, however that reference was written (a manual
  UPDATE that takes no lock, say), is put back by the sweep, which runs after
  every delete, at startup and every few minutes. Only an unreferenced file
  past the retention is removed for good. So a delete frees the server's disk
  space RETENTION_DAYS later; --retention-days 0 removes at once, with no such
  protection.
- That final removal holds the same lock from its "is it referenced?" question
  to the removal. A writer that takes the lock either committed first (its file
  goes back) or waits until the file is gone.

What this guarantees, and what it doesn't. A writer that follows both rules in
catalog_lock.py (take the lock; only reference a file that is in its place)
never ends up pointing at a missing file: set_storage_key.py is that writer,
and brings a retired file back itself. A writer that breaks a rule is covered
only while the file is retired: a reference it writes at or after the moment
of the final removal points at nothing, and nothing here can prevent that.

Replies: 200 deleted, 404 nothing known by that id (already gone), 400/413 a
malformed request, 503 the database wasn't reachable (nothing changed).

Usage (on the server):
    /usr/bin/python3 scripts/cloud/delete_service.py [--port 8081] [--retention-days 7]
Tests:
    /usr/bin/python3 -m unittest scripts/cloud/test_delete_service.py
"""
import argparse
import json
import os
import re
import secrets
import select
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import catalog_lock  # noqa: E402

STORAGE = os.path.expanduser("~/AllSetStorage/wallpapers")
TOKEN_PATH = os.path.expanduser("~/.allset_delete_token")
PSQL = "/opt/homebrew/bin/psql" if os.path.exists("/opt/homebrew/bin/psql") else "psql"
DATABASE_URL = "postgres://allset@localhost/allset"  # local, no tunnel needed here

# Where a wallpaper's rendered files live, each named after its id.
ASSET_DIRS = ("live", "stills", "thumbnails", "transcoded", "extracted", "originals")
ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
MAX_BODY = 16 * 1024
DATABASE_TIMEOUT = 20  # seconds for one psql call
KEY_COLUMNS = ("playback_key", "still_key", "thumbnail_key")
# How long a deleted wallpaper's files stay recoverable before they're removed for good.
RETENTION_DAYS = 7
SWEEP_INTERVAL = 600  # seconds between sweeps of the retired files
# One delete or sweep at a time: both move files in and out of the same places.
BUSY = threading.Lock()


class DatabaseError(Exception):
    pass


def load_or_create_token():
    if os.path.exists(TOKEN_PATH):
        with open(TOKEN_PATH) as handle:
            return handle.read().strip()
    token = secrets.token_hex(32)
    fd = os.open(TOKEN_PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as handle:
        handle.write(token)
    print(f"New delete-service token (put this in the client's Keychain, shown once):\n{token}")
    return token


def safe_path(relative):
    """None unless `relative` resolves strictly inside STORAGE — refuses
    '..', absolute paths, and symlink escapes."""
    if not isinstance(relative, str) or not relative or relative.startswith("/") or ".." in relative.split("/"):
        return None
    resolved = os.path.realpath(os.path.join(STORAGE, relative))
    root = os.path.realpath(STORAGE)
    if resolved != root and not resolved.startswith(root + os.sep):
        return None
    return resolved


def trash_dir(item_id):
    return os.path.join(STORAGE, ".trash", item_id)


def retired_dir(item_id=None):
    root = os.path.join(STORAGE, ".retired")
    return root if item_id is None else os.path.join(root, item_id)


def quote(value):
    # Ids are checked against ID_PATTERN before reaching SQL; quoted regardless.
    return "'" + value.replace("'", "''") + "'"


def sql(statement):
    try:
        result = subprocess.run([PSQL, DATABASE_URL, "-At", "-v", "ON_ERROR_STOP=1", "-c", statement],
                                capture_output=True, text=True, timeout=DATABASE_TIMEOUT)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise DatabaseError(str(error))
    if result.returncode != 0:
        raise DatabaseError(result.stderr.strip() or f"psql exited {result.returncode}")
    return result.stdout.strip()


def sql_script(script):
    """Several statements in one session (so one transaction can span them).
    Returns the output lines."""
    try:
        result = subprocess.run([PSQL, DATABASE_URL, "-q", "-At", "-v", "ON_ERROR_STOP=1", "-f", "-"],
                                input=script, capture_output=True, text=True, timeout=DATABASE_TIMEOUT)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise DatabaseError(str(error))
    if result.returncode != 0:
        raise DatabaseError(result.stderr.strip() or f"psql exited {result.returncode}")
    return result.stdout.splitlines()


class AssetLock:
    """Holds the catalog's asset lock (catalog_lock.py) for as long as the block
    runs, in a database session of its own. For work that decides something from
    the catalog and then acts on files, where one transaction can't cover both:
    while it's held, no writer that takes the lock can change which files are
    referenced. Raises DatabaseError if the lock can't be had in time."""

    def __enter__(self):
        try:
            self.session = subprocess.Popen([PSQL, DATABASE_URL, "-q", "-At", "-v", "ON_ERROR_STOP=1"],
                                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            self.session.stdin.write(f"select pg_advisory_lock({catalog_lock.ASSET_LOCK});\nselect 'held';\n".encode())
            self.session.stdin.flush()
        except OSError as error:
            raise DatabaseError(str(error))
        if not self._answered(b"held", DATABASE_TIMEOUT):
            self._end()
            raise DatabaseError("couldn't take the catalog lock")
        return self

    def __exit__(self, *_):
        self._end()

    def _answered(self, marker, seconds):
        """Whether the session printed `marker` on a line within `seconds`."""
        descriptor = self.session.stdout.fileno()
        deadline, received = time.monotonic() + seconds, b""
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([descriptor], [], [], remaining)[0]:
                return False
            chunk = os.read(descriptor, 4096)
            if not chunk:
                return False  # the session ended: no connection
            received += chunk
            if marker in received.split(b"\n"):
                return True

    def _end(self):
        """Closing the session releases the lock."""
        for pipe in (self.session.stdin, self.session.stdout):
            try:
                pipe.close()
            except OSError:
                pass
        try:
            self.session.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.session.kill()
            self.session.wait()


def text_array(values):
    return "array[%s]::text[]" % ", ".join(quote(value) for value in values)


def delete_row_and_find_shared(item_id, relatives):
    """Deletes the row and says which of `relatives` another row references, in
    one transaction under the catalog's asset lock: no writer that takes the
    lock can add a reference between the question and the delete. The lock is a
    statement of its own, so the next statement sees what a writer it waited
    for committed."""
    marker = "shared:"
    columns = ", ".join("w." + column for column in KEY_COLUMNS)
    lines = sql_script(f"""begin;
select pg_advisory_xact_lock({catalog_lock.ASSET_LOCK});
with gone as (delete from wallpapers where id = {quote(item_id)} returning 1)
select '{marker}' || coalesce(json_agg(m.k), '[]')::text from unnest({text_array(relatives)}) as m(k)
 where exists (select 1 from wallpapers w where w.id <> {quote(item_id)} and m.k in ({columns}));
commit;
""")
    for line in lines:
        if line.startswith(marker):
            return json.loads(line[len(marker):])
    raise DatabaseError("the delete gave no answer")


def referenced_keys(relatives):
    """Which of `relatives` any row references."""
    if not relatives:
        return set()
    out = sql("select coalesce(json_agg(m.k), '[]') from unnest(%s) as m(k) where exists "
              "(select 1 from wallpapers w where m.k in (%s))"
              % (text_array(relatives), ", ".join("w." + column for column in KEY_COLUMNS)))
    return set(json.loads(out or "[]"))


def row_keys(item_id):
    """The row's storage keys, or None if there's no row."""
    out = sql("select coalesce(json_agg(json_build_array(%s)), '[]') from wallpapers where id = %s"
              % (", ".join(KEY_COLUMNS), quote(item_id)))
    rows = json.loads(out or "[]")
    return None if not rows else [key for key in rows[0] if key]


def key_used_elsewhere(key, item_id):
    count = sql("select count(*) from wallpapers where id <> %s and %s in (%s)"
                % (quote(item_id), quote(key), ", ".join(KEY_COLUMNS)))
    return int(count or 0) > 0


def owned_files(item_id, keys):
    """Relative paths of the files that belong to this wallpaper and nothing else:
    named after it or listed in its row, and in neither case referenced by any
    other row (a file named after one wallpaper can still be another's key)."""
    candidates = set()
    for folder in ASSET_DIRS:
        directory = os.path.join(STORAGE, folder)
        if not os.path.isdir(directory):
            continue
        for name in os.listdir(directory):
            stem, _ = os.path.splitext(name)
            if stem == item_id and os.path.isfile(os.path.join(directory, name)):
                candidates.add(f"{folder}/{name}")
    for key in keys or []:
        resolved = safe_path(key)
        if resolved and os.path.isfile(resolved):
            candidates.add(os.path.relpath(resolved, os.path.realpath(STORAGE)))
    return sorted(c for c in candidates if not key_used_elsewhere(c, item_id))


def move(source, destination):
    os.makedirs(os.path.dirname(destination), exist_ok=True)
    os.rename(source, destination)


def restore_quarantine(item_id, only=None):
    """Moves quarantined files back where they were (all, or the relative paths in
    `only`). A file whose place has been taken meanwhile is never overwritten and
    never discarded: it stays held and is returned as a conflict. The quarantine
    folder goes only once nothing is left in it."""
    root = trash_dir(item_id)
    conflicts = []
    for base, _, names in os.walk(root):
        for name in names:
            held = os.path.join(base, name)
            relative = os.path.relpath(held, root)
            if only is not None and relative not in only:
                continue
            destination = safe_path(relative)
            if destination is None or os.path.exists(destination):
                conflicts.append(relative)
                continue
            try:
                move(held, destination)
            except OSError:
                conflicts.append(relative)
    remove_if_empty(root)
    return sorted(conflicts)


def remove_if_empty(root):
    """Removes empty folders under (and including) root; never a file."""
    for base, _, _ in sorted(os.walk(root), key=lambda entry: -len(entry[0])):
        try:
            os.rmdir(base)
        except OSError:
            pass


def settle_quarantine(item_id):
    """A quarantine left by an interrupted delete: back if the row is still there,
    gone if the row is. Raises DatabaseError if that can't be told."""
    if not os.path.isdir(trash_dir(item_id)):
        return []
    if row_keys(item_id) is None:
        # Finished, except files another row started using meanwhile: those go back.
        held = held_files(item_id)
        reused = [relative for relative in held if key_used_elsewhere(relative, item_id)]
        conflicts = restore_quarantine(item_id, only=set(reused)) if reused else []
        # The rest is what that delete was removing: retired like any other.
        retire(item_id, keep=set(conflicts))
        return conflicts
    return restore_quarantine(item_id)


def held_files(item_id):
    root = trash_dir(item_id)
    return sorted(os.path.relpath(os.path.join(base, name), root)
                  for base, _, names in os.walk(root) for name in names)


def retire(item_id, keep=()):
    """Moves what the quarantine still holds (but `keep`) into a retirement
    batch of its own, named by the time. Returns the relative paths retired."""
    batch = os.path.join(retired_dir(item_id), str(time.time_ns()))
    retired = []
    for relative in held_files(item_id):
        if relative in keep:
            continue
        move(os.path.join(trash_dir(item_id), relative), os.path.join(batch, relative))
        retired.append(relative)
    remove_if_empty(trash_dir(item_id))
    return retired


def retired_batches(only=None):
    """(item id, batch folder, time retired in seconds, relative paths) for every
    retirement batch, oldest first within an id."""
    root = retired_dir()
    if not os.path.isdir(root):
        return []
    batches = []
    for item_id in sorted(os.listdir(root)):
        if not ID_PATTERN.match(item_id) or (only is not None and item_id != only):
            continue
        for stamp in sorted(os.listdir(retired_dir(item_id))):
            batch = os.path.join(retired_dir(item_id), stamp)
            if stamp.isdigit() and os.path.isdir(batch):
                files = sorted(os.path.relpath(os.path.join(base, name), batch)
                               for base, _, names in os.walk(batch) for name in names)
                batches.append((item_id, batch, int(stamp) / 1e9, files))
    return batches


def sweep_retired(only=None, now=None):
    """Retired files that a row references go back to their places; the rest
    are removed for good once they've been retired RETENTION_DAYS. Returns
    (restored, removed) relative paths.

    The catalog lock is held from asking which files are referenced until the
    files have been moved or removed, so a writer that takes the lock can't
    commit a reference in between: it either committed first, and its file goes
    back, or it waits and then finds the file gone (and, following the rule to
    reference only files that exist, doesn't reference it). A database that
    can't be asked, or a lock that can't be had, changes nothing: everything
    stays retired."""
    restored, removed = [], []
    now = time.time() if now is None else now
    batches = retired_batches(only)
    if not batches:
        return restored, removed
    try:
        with AssetLock():
            for item_id, batch, retired_at, files in batches:
                try:
                    referenced = referenced_keys(files)
                except DatabaseError as error:
                    print(f"Couldn't check retired files of {item_id}: {error}", file=sys.stderr)
                    continue
                expired = now - retired_at >= RETENTION_DAYS * 86400
                for relative in files:
                    destination = safe_path(relative)
                    if relative in referenced and destination is not None and not os.path.exists(destination):
                        move(os.path.join(batch, relative), destination)
                        restored.append(relative)
                    elif expired and relative not in referenced:
                        os.remove(os.path.join(batch, relative))
                        removed.append(relative)
                remove_if_empty(batch)
                remove_if_empty(retired_dir(item_id))
    except DatabaseError as error:
        print(f"Couldn't sweep retired files: {error}", file=sys.stderr)
    return restored, removed


def reference_asset(item_id, column, key):
    """The supported way to point a row at a file in storage: None when done,
    or why it wasn't.

    Under the catalog lock, so it can't interleave with a delete or a purge. The
    file must be in its place; one that's retired (its wallpaper was deleted) is
    brought back first. A file that's nowhere is never referenced, so a row can't
    be left pointing at nothing."""
    if column not in KEY_COLUMNS:
        return f"not a storage key column: {column} (one of {', '.join(KEY_COLUMNS)})"
    if not isinstance(item_id, str) or not ID_PATTERN.match(item_id):
        return "not a valid id"
    destination = safe_path(key)
    if destination is None:
        return f"outside the storage folder: {key}"
    relative = os.path.relpath(destination, os.path.realpath(STORAGE))
    try:
        with AssetLock():
            if row_keys(item_id) is None:
                return f"no wallpaper with id {item_id}"
            if not os.path.isfile(destination):
                # Retired with the wallpaper it belonged to: the most recent copy comes back.
                held = [(retired_at, batch) for _, batch, retired_at, files in retired_batches() if relative in files]
                if not held:
                    return f"no such file in storage: {relative}"
                _, batch = max(held)
                move(os.path.join(batch, relative), destination)
                remove_if_empty(batch)
                remove_if_empty(os.path.dirname(batch))
            sql("update wallpapers set %s = %s where id = %s" % (column, quote(relative), quote(item_id)))
            return None
    except DatabaseError as error:
        return f"database unavailable: {error.args[0]}"


def sweep_forever():
    while True:
        time.sleep(SWEEP_INTERVAL)
        with BUSY:
            try:
                sweep_retired()
            except OSError as error:
                print(f"Sweeping retired files failed: {error}", file=sys.stderr)


def settle_all_quarantines():
    root = os.path.join(STORAGE, ".trash")
    if not os.path.isdir(root):
        return
    for item_id in os.listdir(root):
        if ID_PATTERN.match(item_id):
            try:
                conflicts = settle_quarantine(item_id)
            except DatabaseError as error:
                print(f"Couldn't settle the quarantine for {item_id}: {error}", file=sys.stderr)
                continue
            if conflicts:
                print(f"Kept in {trash_dir(item_id)} (their places are taken): {', '.join(conflicts)}", file=sys.stderr)


def delete_wallpaper(item_id):
    """(status, body) for deleting one wallpaper everywhere on this server."""
    with BUSY:
        return _delete_wallpaper(item_id)


def _delete_wallpaper(item_id):
    try:
        conflicts = settle_quarantine(item_id)
        if conflicts:
            return 409, {"error": "an earlier delete left files whose places are taken; resolve them by hand",
                         "conflicts": conflicts, "quarantine": trash_dir(item_id)}
        keys = row_keys(item_id)
        files = owned_files(item_id, keys)
    except DatabaseError as error:
        return 503, {"error": "database unavailable; nothing was deleted", "detail": error.args[0]}
    if keys is None and not files:
        return 404, {"error": "unknown id", "id": item_id}

    moved = []
    try:
        for relative in files:
            move(os.path.join(STORAGE, relative), os.path.join(trash_dir(item_id), relative))
            moved.append(relative)
    except OSError as error:
        conflicts = restore_quarantine(item_id)
        return 500, {"error": "couldn't move the files aside; nothing was deleted", "detail": str(error),
                     **({"conflicts": conflicts} if conflicts else {})}

    # The row goes, and "does another row use these files?" is answered, as one
    # step under the catalog's lock.
    try:
        reused = delete_row_and_find_shared(item_id, moved)
    except DatabaseError as error:
        conflicts = restore_quarantine(item_id)
        body = {"error": "database delete failed; files restored, nothing was deleted", "detail": error.args[0]}
        if conflicts:
            body.update(error="database delete failed; some files' places were taken meanwhile, so those "
                              "originals are kept in quarantine (nothing was lost)",
                        conflicts=conflicts, quarantine=trash_dir(item_id))
        return 503, body

    conflicts = restore_quarantine(item_id, only=set(reused)) if reused else []
    # Everything still held is what this delete removes, except a conflict, which
    # stays. Retired, not destroyed: a reference written since the check above by
    # something that doesn't take the lock gets its file back, now or at a later sweep.
    retire(item_id, keep=set(conflicts))
    restored, _ = sweep_retired(only=item_id)
    removed = [relative for relative in moved if relative not in reused and relative not in restored]
    kept = sorted(set(reused) | set(restored))
    return 200, {"removedFiles": removed, "database": "deleted" if keys is not None else "no row",
                 "recoverableDays": RETENTION_DAYS,
                 **({"keptBecauseShared": kept} if kept else {}),
                 **({"conflicts": conflicts} if conflicts else {})}


class Handler(BaseHTTPRequestHandler):
    token = None  # set in main()
    timeout = 15  # seconds a client may take to send its request

    def _reply(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _authorized(self):
        given = self.headers.get("Authorization", "")
        return secrets.compare_digest(given, f"Bearer {self.token}")

    def do_DELETE(self):
        if self.path != "/wallpaper":
            self._reply(404, {"error": "not found"})
            return
        if not self._authorized():
            self._reply(401, {"error": "bad token"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self._reply(400, {"error": "bad Content-Length"})
            return
        if length <= 0 or length > MAX_BODY:
            self._reply(413 if length > MAX_BODY else 400, {"error": f"body must be 1–{MAX_BODY} bytes"})
            return
        try:
            payload = json.loads(self.rfile.read(length))
        except (ValueError, UnicodeDecodeError, OSError):
            self._reply(400, {"error": "expected a JSON object {id}"})
            return
        item_id = payload.get("id") if isinstance(payload, dict) else None
        if not isinstance(item_id, str) or not ID_PATTERN.match(item_id):
            self._reply(400, {"error": "expected a JSON object {id} with a valid id"})
            return
        status, body = delete_wallpaper(item_id)
        if status >= 500:
            print(f"delete {item_id}: {status} {body.get('error')}", file=sys.stderr)
        self._reply(status, body)

    def log_message(self, format, *args):
        pass  # never log secrets or noisy per-request lines; failures go to stderr above


def main():
    global RETENTION_DAYS
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8081)
    parser.add_argument("--retention-days", type=float, default=RETENTION_DAYS,
                        help="how long a deleted wallpaper's files stay recoverable (0: removed at once)")
    args = parser.parse_args()
    RETENTION_DAYS = args.retention_days
    Handler.token = load_or_create_token()
    settle_all_quarantines()
    restored, removed = sweep_retired()
    if restored or removed:
        print(f"Retired files: {len(restored)} put back (a row uses them), "
              f"{len(removed)} removed after {RETENTION_DAYS} days")
    threading.Thread(target=sweep_forever, daemon=True).start()
    server = HTTPServer(("127.0.0.1", args.port), Handler)
    print(f"delete service on 127.0.0.1:{args.port} (localhost only; reach it through the SSH tunnel)")
    server.serve_forever()


if __name__ == "__main__":
    main()
