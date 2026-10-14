# Running the wallpaper server

This describes the one deployment that exists: a personal home server reached over Tailscale. It records what the scripts in `scripts/cloud/` do, how to set the server up with them, and what is still missing. Nothing here is needed to use All Set without a server.

Last checked against the scripts on 2026-10-06.

**Written and tested, not yet run on the server.** The supervision, backup, restore drill and migration tools below were added on 2026-10-06. They pass their tests against a throwaway Postgres and temporary folders. Nobody has run them on the real server yet. The "First-time setup" section is the list of commands that does that.

## What runs where

| Piece | Where | How it is reached | How it starts |
|---|---|---|---|
| Postgres, database `allset`, table `wallpapers` | Server, bound to localhost | SSH tunnel from the Mac (`tunnel.sh`, port 5432) | launchd on the server |
| Wallpaper files, `~/AllSetStorage/wallpapers` | Server | Caddy over plain HTTP on the Tailscale address. The app fetches `<server URL>/<relative path>`, for example `live/<id>.mp4` | launchd on the server |
| Delete service, `delete_service.py`, port 8081 | Server, bound to localhost | The same SSH tunnel | By hand today; launchd once `install_services.py` has been run |
| Catalog service for a tester, `catalog_service.py`, port 8082 | Server, Tailscale address only | Directly over Tailscale, bearer token | By hand today; launchd once `install_services.py` has been run |
| Nightly backup and restore drill, `backup.py` | Server | Runs by itself at 03:30 | Not scheduled until `install_services.py --backups <folder>` has been run |

The server's layout mirrors the Mac's library folder, so a relative path means the same file on both sides.

On the Mac:

- `tunnel.sh` holds the SSH tunnel open. It forwards 5432 and 8081 to the server alias `allset-server` from `~/.ssh/config`.
- `push_wallpapers.sh` copies the library's files to the server with rsync. It never deletes on the server.
- `sync_catalog.py` uploads catalog metadata to Postgres through the tunnel. It reads `DATABASE_URL` from `scripts/cloud/.env`.
- `migrate.py` brings the database's schema up to date through the tunnel.
- The app is built with `ALLSET_LIBRARY_SERVER_HOST` (or `scripts/local.env`), which allows plain HTTP to that one host.

The headers of `sync_catalog.py` and `migrations/0001_initial.sql` still mention Neon and Cloudflare R2. The deployment in use is the home server above. Those headers need correcting by someone who knows whether the cloud plan is still intended.

## First-time setup of the new tools

Do these once, in this order. Each is safe to run again.

1. **Adopt migrations.** On the Mac, with the tunnel open: `/usr/bin/python3 scripts/cloud/migrate.py --status`, then `/usr/bin/python3 scripts/cloud/migrate.py`. The existing database is adopted as it is: step 0001 only creates what is missing, and your rows stay.
2. **Take one backup and drill it by hand.** On the server: `/usr/bin/python3 scripts/cloud/backup.py backup <folder on another disk> --drill`. It should end with "Restore drill passed". If it does not, stop here and read what it lists.
3. **Put the services and the nightly backup under launchd.** On the server: `/usr/bin/python3 scripts/cloud/install_services.py --backups <the same folder>`. To see the files first without installing, add `--print <some folder>`.
4. **Check.** `launchctl list | grep com.allset` on the server shows three jobs. From the Mac, `scripts/cloud/tunnel.sh --check` still says the tunnel is up.

To undo step 3: `/usr/bin/python3 scripts/cloud/install_services.py --uninstall`.

## Checking that each piece is up

| Piece | Check | Healthy answer |
|---|---|---|
| Tunnel | `scripts/cloud/tunnel.sh --check` | "tunnel is up". Both ports must be held by ssh and the delete service must answer. A local Postgres on 5432 is reported as not the tunnel |
| Postgres | With the tunnel open: `psql "$DATABASE_URL" -c "select count(*) from wallpapers"` | A row count |
| Schema | `/usr/bin/python3 scripts/cloud/migrate.py --status` | Every step "applied" |
| File server | `curl -I "<server URL>/thumbnails/<an id>.jpg"` from the Mac | `200` with a `Content-Length` |
| Delete service | Covered by `tunnel.sh --check` | Any HTTP answer through the tunnel |
| Catalog service | `curl -H "Authorization: Bearer <token>" "http://<tailscale address>:8082/catalog?limit=1"` | A JSON list and an `X-Total-Count` header |
| Services under launchd | On the server: `launchctl list \| grep com.allset` | Three lines; the first column is a process id for the two services |
| Last night's backup | On the server: `tail ~/Library/Logs/AllSet/backup.log` | "Restore drill passed for …" |

The app's own "checked on your server" count is stronger evidence than any of these for a given file: it means that file's server copy matched this Mac's by size and SHA-256 when the local copy was freed.

## Tokens

| Token | File on the server | Rotation |
|---|---|---|
| Delete service | `~/.allset_delete_token` (chmod 600) | Created and printed once on first run. Delete the file and restart the service to make a new one, then save the new token in the app (it is kept in the Mac's Keychain) |
| Catalog service | `~/.allset_catalog_token` (chmod 600) | Delete the file and restart the service |
| Postgres password | `~/.allset_pg_credentials` on the server, `scripts/cloud/.env` on the Mac | Change it in Postgres, then in both files |

A delete needs three things in order: this Mac's SSH key (for the tunnel), the delete token, and Touch ID or the Mac password in the app.

Under launchd a service is restarted with `launchctl kickstart -k gui/$(id -u)/com.allset.delete-service` (or `…catalog-service`). A token printed on first run goes to the service's log in `~/Library/Logs/AllSet/`.

## Deleting, and writing storage keys

A delete from the app removes the wallpaper's row and retires its files. Retired files move to `~/AllSetStorage/wallpapers/.retired/<id>/<time>/` and stay there for 7 days (`--retention-days`), so **a delete frees the server's disk space a week later, not at once**.

That window is what protects a file another wallpaper comes to use:

- **Set storage keys with `scripts/cloud/set_storage_key.py <id> <column> <relative path>`**, on the server, after the file has been pushed. It takes the catalog lock, only references a file that is in its place, and brings a retired file back if that is what you point at. A row set this way never points at a missing file.
- The lock is `select pg_advisory_xact_lock(<ASSET_LOCK>)`, with the number in `scripts/cloud/catalog_lock.py`. The delete service takes it around a row delete and around the final removal of retired files; `sync_catalog.py` takes it around its upsert, and `migrate.py` around each step.
- **An `UPDATE` typed into psql is not protected in the same way.** While the file it points at is still retired, the delete service puts it back (it checks after every delete, at startup and every 10 minutes). If the update lands at or after the moment a retired file is finally removed, the row points at nothing, and nothing in these scripts can prevent that. Use the command above instead.
- After the retention, an unreferenced retired file is removed for good.

`.trash/<id>/` is different: it holds files only while one delete is in progress, and is settled at the next start if the service stopped midway.

## Backups and restoring

`backup.py backup <folder>` writes `<folder>/<UTC time>/` with three things: `allset.sql` (the database, from `pg_dump`), `files/` (a copy of the storage folder) and `manifest.json` (the row count and every file's size and SHA-256). A file unchanged since the previous backup is a hard link to it, so a quiet night costs almost no space. The newest 7 are kept (`--keep`).

Put `<folder>` on a different disk from `~/AllSetStorage`. A backup on the same disk does not survive that disk.

**The drill is the proof.** `backup.py drill <one backup's folder>` restores that backup into a scratch database and a scratch folder, checks that the dump loads, the row count matches, every file matches its checksum and every file a row points at is there, then removes the scratch copies. It exits 0 only if all of that held. The nightly job runs a drill after every backup. Retention removes older backups only after the replacement passes its drill; a failed or unavailable drill keeps the older copies. A backup that has never passed a drill should not be relied on.

**Restoring for real** uses the same code the drill runs: `backup.py restore <backup folder> --database-url <url> --storage <folder>`. It only writes into a database with no `wallpapers` table and an empty folder, and never overwrites. To replace a damaged server:

1. Stop the services: `install_services.py --uninstall`.
2. Move the damaged database and storage folder aside. Do not delete them yet.
3. Create an empty database, then run `backup.py restore` into it and into the usual storage path.
4. Run `migrate.py`, then `install_services.py --backups <folder>` again.

Limits:

- The database and the files are copied one after the other. A wallpaper deleted in between can leave one backup whose rows and files disagree. The drill reports that, and the next night's backup is whole.
- Hard links mean one damaged file on the backup disk is damaged in every backup that shares it. The drill re-reads every file, so it shows up the next night.
- A delete still in progress (`.trash`) is not backed up. Retired files are.
- This backs up the server. It does not back up the Mac's own All Set data.

## Schema changes

The schema is the numbered files in `scripts/cloud/migrations/`. `migrate.py` applies the ones not yet recorded in the `schema_migrations` table, in name order, each in its own transaction. A step that fails is rolled back and the run stops there.

To change the schema, add the next numbered file (`0002_….sql`) and run `migrate.py`. Never edit a file that has been applied anywhere.

## The catalog service's limits

`GET /catalog` returns the whole list, as before. `GET /catalog?limit=N&offset=M` (N from 1 to 500) returns one page in the same shape, with `X-Total-Count` and, unless it is the last page, `X-Next-Offset`. A page can hold fewer than N items, because rows whose file is not on the server are left out.

It serves 8 requests at a time. A ninth gets `503` with `Retry-After: 1`. It still runs `psql` once per request, which is fine for a few testers and not for many.

## Tests

`/usr/bin/python3 -m unittest scripts/cloud/test_sync_catalog.py scripts/cloud/test_delete_service.py scripts/cloud/test_catalog_service.py scripts/cloud/test_migrate.py scripts/cloud/test_backup.py scripts/cloud/test_install_services.py` runs the server scripts against a throwaway Postgres 17 (`pgtest.py`). CI runs the same tests and fails if any are skipped.

## Still missing

- **Running any of the new tools on the real server.** See the note at the top.
- **An automatic upload step.** `push_wallpapers.sh` copies files and stops there; nothing sets the storage keys afterwards except a person running `set_storage_key.py`, one key at a time. A script that pushes and then sets every key does not exist yet.
- **An off-site copy.** The nightly backup goes to a folder you choose on the server. Nothing copies it anywhere else.
- **Alerts.** A failed drill is in `backup.log` and in the job's exit code. Nothing tells you unless you look.
- **Running without a login.** The launch agents run while the server's account is logged in. A server that restarts needs automatic login, as Homebrew's Postgres already does.
