"""Uploads the wallpaper catalog's metadata to the cloud Postgres (Neon).

Metadata only — this does not touch the actual video/still/thumbnail files
(those go to object storage separately, once R2 is wired up). Safe to run
again: loads into a staging table, then upserts by id, so a rerun updates
rows instead of duplicating them. It never changes a row's storage keys:
new rows start without them, and keys an upload filled in are kept.

Tests: /usr/bin/python3 -m unittest scripts/cloud/test_sync_catalog.py

Needs `psql` (already on this Mac via Homebrew) and a `.env` file next to
this script with:
    DATABASE_URL=postgres://allset:PASSWORD@localhost:5432/allset

The home server's Postgres is bound to localhost there, so "localhost" in
that URL means the server's database only while the SSH tunnel is open:

    scripts/cloud/tunnel.sh      # in one terminal, leave it running
    /usr/bin/python3 scripts/cloud/sync_catalog.py

Run scripts/cloud/tunnel.sh --check if you're unsure the tunnel is up. A
local Postgres listening on 5432 would silently take its place, so the
tunnel script refuses to start when the port is already busy.
"""
import csv
import io
import json
import os
import socket
import subprocess
import sys
import urllib.parse


def tunnel_is_open(port=5432):
    """Whether anything is listening locally: without the tunnel, the sync
    would either fail or, worse, write to a local Postgres instead."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.settimeout(0.5)
        return probe.connect_ex(("127.0.0.1", port)) == 0

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import catalog_lock  # noqa: E402

PSQL ="/opt/homebrew/bin/psql" if os.path.exists("/opt/homebrew/bin/psql") else "psql"

COLUMNS = ["id", "title", "kind", "category", "tags", "origin_root", "origin_file",
           "playback_key", "still_key", "thumbnail_key", "duration", "width", "height",
           "fps", "size_bytes", "status", "status_reason", "provenance", "content_rating", "added_at"]

# Where each uploaded file lives. The catalog never knows them (the upload step
# writes them), so a rerun must leave them alone: updating them from this sync
# would set every uploaded row's keys back to NULL and break playback.
STORAGE_KEYS = {"playback_key", "still_key", "thumbnail_key"}


def load_env(path):
    env = dict(os.environ)
    if os.path.exists(path):
        for line in open(path):
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def database_url(env):
    """The server's database, through the tunnel. The password comes from the
    login keychain, so it isn't sitting in a readable file; DATABASE_URL in
    the environment or .env still wins if it's set, for a one-off elsewhere.

    Put it in the keychain once with:
        security add-generic-password -s allset-postgres -a allset -w '<password>'
    """
    if env.get("DATABASE_URL"):
        return env["DATABASE_URL"]
    found = subprocess.run(["security", "find-generic-password", "-s", "allset-postgres", "-a", "allset", "-w"],
                           capture_output=True, text=True)
    if found.returncode != 0:
        return None
    password = found.stdout.strip()
    return f"postgres://allset:{urllib.parse.quote(password, safe='')}@localhost:5432/allset"


def pg_array(values):
    # Postgres text[] literal for COPY: {a,b,"has space"}
    if not values:
        return "{}"
    parts = []
    for v in values:
        v = str(v).replace("\\", "\\\\").replace('"', '\\"')
        parts.append(f'"{v}"' if ("," in v or " " in v or '"' in v) else v)
    return "{" + ",".join(parts) + "}"


def row_for(item):
    provenance = item.get("provenance")
    return [
        item["id"], item.get("title", "Untitled"), item.get("kind", "video"),
        item.get("category", "abstract"), pg_array(item.get("tags", [])),
        item.get("root"), item.get("file"),
        None, None, None,  # storage keys: filled in once files are uploaded to R2
        item.get("duration"), item.get("width"), item.get("height"), item.get("fps"),
        item.get("size"), item.get("status", "quarantined"), item.get("statusReason"),
        json.dumps(provenance) if provenance else None,
        item.get("contentRating"), item.get("addedAt"),
    ]


def main():
    env = load_env(os.path.join(HERE, ".env"))
    url = database_url(env)
    if not url:
        sys.exit("No database password in the keychain, and no DATABASE_URL set.\n"
                 "    security add-generic-password -s allset-postgres -a allset -w '<password>'")
    if not tunnel_is_open():
        sys.exit("Nothing is listening on localhost:5432 — open the tunnel first:\n"
                 "    scripts/cloud/tunnel.sh")

    library = env.get("ALLSET_LIBRARY") or os.path.expanduser(
        "~/Library/Application Support/AllSet/Wallpaper/Library")
    with open(os.path.join(library, "catalog.json")) as handle:
        all_items = json.load(handle)["items"]
    items = [i for i in all_items if i.get("status") != "unsupported"]
    print(f"{len(items)} wallpapers to sync (of {len(all_items)} total)")

    buf = io.StringIO()
    # Postgres's CSV reader takes its line ending from the first line, and the
    # end-of-data marker below ends in "\n": the csv module's default "\r\n"
    # makes COPY fail with "unquoted newline found in data".
    writer = csv.writer(buf, lineterminator="\n")
    writer.writerow(COLUMNS)
    for item in items:
        writer.writerow(row_for(item))

    cols = ",".join(COLUMNS)
    updates = ",\n    ".join(f"{c} = excluded.{c}" for c in COLUMNS if c != "id" and c not in STORAGE_KEYS)
    script = f"""
create schema if not exists staging;
drop table if exists staging.wallpapers;
create table staging.wallpapers (like wallpapers including all);
\\copy staging.wallpapers ({cols}) from stdin with (format csv, header true)
{buf.getvalue()}\\.
begin;
-- The lock every catalog writer takes (catalog_lock.py): a delete on the server
-- can't interleave with this.
select pg_advisory_xact_lock({catalog_lock.ASSET_LOCK});
insert into wallpapers ({cols}, synced_at)
select {cols}, now() from staging.wallpapers
on conflict (id) do update set
    {updates},
    synced_at = now();
commit;
drop table staging.wallpapers;
select count(*) as total_in_cloud from wallpapers;
"""

    proc = subprocess.run([PSQL, url, "-v", "ON_ERROR_STOP=1", "-f", "-"],
                          input=script, capture_output=True, text=True)
    print(proc.stdout)
    if proc.returncode != 0:
        print(proc.stderr, file=sys.stderr)
        sys.exit(1)
    print("Synced.")


if __name__ == "__main__":
    main()
