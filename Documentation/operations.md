# Running the wallpaper server

This describes the one deployment that exists: a personal home server reached over Tailscale. It records what the scripts in `scripts/cloud/` do, how to set the server up with them, and what is still missing. Nothing here is needed to use All Set without a server.

**What this is, plainly:** a personal server on the owner's own Mac, for the owner and a few people they share a key with. Inside Tailscale it serves plain HTTP; it is not exposed to the internet and must not be ("never forward the port"). It runs on Python's standard-library HTTP server and psql, which suit a handful of users, not the public. The "public library" pieces (`publish_catalog.py`, `Caddyfile.public`) are built and tested locally but not deployed, and publish only licence-cleared rows: today zero. The app works fully without any server (36 built-in wallpapers). A plan for real public content is in `public-content-backend.md`.

**2026-10-17:** every SQL value now travels as a psql variable or COPY data (`pgsql.py`); `/catalog` is cached for 30 s and counts only rows with a file before paging.

Last checked against the scripts on 2026-10-06.

**Written and tested, not yet run on the server.** The supervision, backup, restore drill and migration tools below were added on 2026-10-06. They pass their tests against a throwaway Postgres and temporary folders. Nobody has run them on the real server yet. The "First-time setup" section is the list of commands that does that.

## What runs where

| Piece | Where | How it is reached | How it starts |
|---|---|---|---|
| Postgres, database `allset`, table `wallpapers` | Server, bound to localhost | SSH tunnel from the Mac (`tunnel.sh`, port 5432) | launchd on the server |
| Wallpaper files, `~/AllSetStorage/wallpapers` | Server | Caddy over plain HTTP on the Tailscale address. The app fetches `<server URL>/<relative path>`, for example `live/<id>.mp4` | launchd on the server |
| Delete service, `delete_service.py`, port 8081 | Server, bound to localhost | The same SSH tunnel | By hand today; launchd once `install_services.py` has been run |
| Catalog service, `catalog_service.py`, port 8082 | Server, Tailscale address only | Through Caddy at `<server URL>/api/`. Caddy asks its `/me` before serving any wallpaper file. Bearer token: the permanent API key, or a session from `/login` (`accounts.py`) | By hand: `scripts/cloud/deploy_catalog.sh` copies it over and restarts it |
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
| Catalog service | `scripts/cloud/deploy_catalog.sh` ends with this check; by hand on the server: `curl -H "Authorization: Bearer $(cat ~/.allset_catalog_token)" "<server URL>/api/library"` | `200` with the key, `401` without it |
| Services under launchd | On the server: `launchctl list \| grep com.allset` | Three lines; the first column is a process id for the two services |
| Last night's backup | On the server: `tail ~/Library/Logs/AllSet/backup.log` | "Restore drill passed for …" |

The app's own "checked on your server" count is stronger evidence than any of these for a given file: it means that file's server copy matched this Mac's by size and SHA-256 when the local copy was freed.

## Tokens

| Token | File on the server | Rotation |
|---|---|---|
| Delete service | `~/.allset_delete_token` (chmod 600) | Created and printed once on first run. Delete the file and restart the service to make a new one, then save the new token in the app (it is kept in the Mac's Keychain) |
| Catalog service API key | `~/.allset_catalog_token` (chmod 600) on the server; in the Keychain on each Mac it was given to (`AllSet library <key>`) | One key, reusable, never expires. To stop accepting it, delete the file and restart the service; a new file with a new key needs the command run again on every Mac |
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

## A public library (built 2026-10-09; run on the dev Mac only, not on the internet)

People who install the app get wallpapers over HTTPS from a public folder, with no Tailscale, no key and no sign-in. Postgres and the storage folder stay private. All of it runs on one Mac and talks only to `127.0.0.1`. The user's rule: no part of this may need Tailscale, and Tailscale is to be uninstalled once the data is moved.

### The pieces

| Piece | What it does |
|---|---|
| `scripts/cloud/server.sh` | Runs the server in one folder, `$ALLSET_SERVER_DIR` (default `~/Downloads/allSetServer`): Postgres 17 on `127.0.0.1:5433`, `storage/wallpapers`, `public`, `backups`, `logs`, `database.env` (generated password). Every command below is one of its subcommands |
| `load [library folder]` (`sync_catalog.py`, then `load_library.py`) | A library's list into the database, its files into storage, and each row pointed at its files. On one Mac, so no tunnel and no rsync over SSH. Run again, it copies only what is new. Never deletes, never clears a key |
| `publish [--dry-run]` (`publish_catalog.py`) | Builds `public/`: `catalog.json` (the app's catalog shape, plus `revision` and a SHA-256 of each file) and each listed file at its storage path, as a hard link. Files first, then the list, then what is no longer listed is removed |
| `serve` (`Caddyfile.public`) | Caddy on `public/` and nothing else: read-only, no folder listings, no dot files. `127.0.0.1:8090` unless the folder's `server.env` sets `ALLSET_PUBLIC_SITE` and `ALLSET_PUBLIC_BIND` |
| `backup` (`backup.py`) | A backup into `backups/`, then restored into scratch copies and checked |
| `install` / `uninstall` (`install_public_server.py`) | Three launch agents: Postgres and Caddy kept running from login, and the backup every night at 03:30 |
| `sample` (`dev_sample.py`) | Three made-up CC0 wallpapers, so there is something that may be published |

**What a publish lets out:** rows with status `published` whose provenance records a license and whose file is in storage. There is no flag to include quarantined rows. A published row with no license is left out and listed in the output. It publishes the title, category, tags, sizes, author and license; never `origin_root`, `origin_file` or a Workshop id.

**Taking a wallpaper down:** unpublish or delete its row, then `publish`. Until the second step it is still public.

**The app:** a copy built with `ALLSET_PUBLIC_LIBRARY_URL` (environment, `scripts/local.env`, or the repository variable of that name for a release) reads `<address>/catalog.json` by itself at launch and every six hours, with no key (`LibrarySync.update()`, `AppServices.startPublicLibrary`). It never sends the library key there. Both download paths throw away a file whose SHA-256 isn't the one the catalog lists. Such a copy carries nothing of the private server: `build-app.sh` leaves out its address and its plain-HTTP exception. A Mac with an imported library of its own keeps its list and ignores the public one.

### What was run, and what it showed (2026-10-09, dev Mac)

- `load`: 986 rows, 1,011 files (1.3 GB) into storage. **1,784 files the catalog names are not on this Mac**: only 25 of the 986 wallpapers have their video here; the rest were freed and exist only on the home server. Moving the library needs that Mac.
- `publish`: the three samples went out; none of the 986 quarantined rows did.
- `serve`, checked with curl: list and files answer, range requests and `If-None-Match` work; paths out of the folder, the database folder, `POST`, `PUT`, `DELETE` are refused.
- `ALLSET_PUBLIC_LIBRARY_TEST_URL=http://127.0.0.1:8090 swift test --filter PublicLibraryLiveTests` (with `serve` running): the app's sync code over real HTTP, every file and checksum. Passed. The same command with the real address checks the real server.
- `backup`: 989 rows and 1,019 files, restore drill passed.
- `install`, on a throwaway copy in the home folder: both services started, came back within seconds of being killed, and the nightly job's backup passed its drill. Then uninstalled.
- A release build with a public address: no Tailscale address anywhere in the app bundle.

### Known limits

- **`install` does not work from `~/Downloads`, `~/Desktop` or `~/Documents`.** macOS refuses a login service access to them ("Operation not permitted"). Both the repository and the default server folder are in Downloads on the dev Mac, so `install` refuses there and says so. On the Mac that serves, keep the scripts and the folder elsewhere (`~/AllSetServer`, with `ALLSET_SERVER_DIR` set).
- **No limit on requests per client.** Stock Caddy has none; the config only times out idle connections. The limit belongs to what stands in front (a tunnel or CDN).
- **Backups go to the same disk** unless `backups/` is moved or linked to another one.
- **`load` treats a file of the same size as the same file.** A re-render of exactly the same length is not copied again.
- **Not checked: the running app showing a public library.** The dev Mac has its own library, so the app skips the public one there.
- A leftover test folder, `~/AllSetServerTest`, can be deleted by hand (removing it was refused to the assistant).

### To move the server to another Mac

1. Here: `server.sh uninstall` (if installed), `server.sh stop`.
2. Copy the whole server folder and `scripts/cloud` to the other Mac, outside Downloads, by disk or AirDrop.
3. There: `brew install postgresql@17 caddy`, set `ALLSET_SERVER_DIR`, `server.sh start`, `server.sh publish`, `server.sh install`.

Both Macs must be Apple silicon: the database folder is copied as it is.

### To go public (only the user can do these)

1. **Content.** Every wallpaper in the library is quarantined, so the real public catalog is empty. Mark what may be shared as `published`, with its license in the provenance.
2. **The files.** Bring the 1,784 freed files back from the home server while it can still be reached, then `load`.
3. **An address.** A domain, then either a tunnel to `127.0.0.1:8090`, or the router forwarding 443 with `ALLSET_PUBLIC_SITE=library.example.com` and `ALLSET_PUBLIC_BIND=0.0.0.0` in `server.env` (Caddy then gets its certificate by itself). A free Cloudflare tunnel is not meant for serving video; a bucket is the later answer.
4. **A release.** Set the repository variable `ALLSET_PUBLIC_LIBRARY_URL`, add the Apple signing secrets `release.yml` lists, push a `v*` tag.

### What stops working when Tailscale is uninstalled

`tunnel.sh`, `push_wallpapers.sh`, `deploy_catalog.sh`, `catalog_service.py` (it listens on the Tailscale address), `Caddyfile.example`, and `AllSet library <key>` against the home server. Nothing in the table above uses any of them.

## Tests

`/usr/bin/python3 -m unittest discover -s scripts/cloud -p "test_*.py"` runs every server test (100 on 2026-10-09). `/usr/bin/python3 -m unittest scripts/cloud/test_sync_catalog.py scripts/cloud/test_delete_service.py scripts/cloud/test_catalog_service.py scripts/cloud/test_migrate.py scripts/cloud/test_backup.py scripts/cloud/test_install_services.py` runs the server scripts against a throwaway Postgres 17 (`pgtest.py`). CI runs the same tests and fails if any are skipped.

## Still missing

- **Running any of the new tools on the real server.** See the note at the top.
- **An automatic upload step.** `push_wallpapers.sh` copies files and stops there; nothing sets the storage keys afterwards except a person running `set_storage_key.py`, one key at a time. A script that pushes and then sets every key does not exist yet.
- **An off-site copy.** The nightly backup goes to a folder you choose on the server. Nothing copies it anywhere else.
- **Alerts.** A failed drill is in `backup.log` and in the job's exit code. Nothing tells you unless you look.
- **Running without a login.** The launch agents run while the server's account is logged in. A server that restarts needs automatic login, as Homebrew's Postgres already does.

## Sharing the library with another Mac

The other Mac gets a copy of the app with the server URL built in (`scripts/build-app.sh` reads `ALLSET_LIBRARY_SERVER_URL` from `scripts/local.env`) and the server's API key. It must be able to reach the server's Tailscale address: share the server machine with that person's Tailscale account from the Tailscale admin console.

On that Mac, once the app is in Applications:

```sh
/Applications/AllSet.app/Contents/MacOS/AllSet library <key>
```

The command checks the key with the server, saves it in the Keychain, writes the server's list as `Library/catalog.json`, downloads the pictures, then the wallpapers smallest first, leaving 10 GB free. `--list-only` stops after the pictures. Run again, it downloads only what is missing. The running app reads the list again as files land, and fetches any wallpaper that isn't there when it is picked.

On a Mac with its own imported library the command only saves the key; `catalog.json` there is never replaced.

## Access keys (app side built 2026-10-18; server side not live yet)

Nothing in the app starts until the public library (`AllSetPublicLibraryURL`, e.g. https://wallpapers.oddmunks.com) accepts an access key. App code: `Sources/AllSetCore/Access/` (state machine, Keychain, the one place the token is added to library requests) and `Sources/AllSet/Access/` (the gate around launch, the key window).

The contract the server implements:

| Request | Answers |
|---|---|
| `POST /api/activate` `{"key": "ALLSET-XXXX-XXXX-XXXX"}` (the app strips spaces and uppercases) | 200 `{"token", "name", "expiresAt"}` (ISO 8601); 401 `{"error": "This key isn't valid."}`; 429 `{"error": "Too many attempts. Try again in a few minutes."}` |
| `GET /api/me` with `Authorization: Bearer <token>` | 200 `{"name", "expiresAt"}`; 401 when the token expired or its key was revoked |
| Every library file (`catalog.json`, `live/`, `stills/`, `thumbnails/`) | needs `Authorization: Bearer <token>`; 401 without it or with a bad one |

How the app behaves:
- Launch with a saved token: `/api/me`. A 401 re-activates quietly with the saved key; only a 401 to that locks the app (Keychain cleared, key screen). No answer: a token whose `expiresAt` hasn't passed unlocks in offline mode, checked again when the network returns and every 5 minutes.
- A 401 from a library file renews the token the same way, at most once a minute. If the key turns out revoked while the app runs, it restarts at the key screen.
- The key and the token live in the Keychain (service `com.pratik.allset.access`), never in UserDefaults or `wallpaper.json`. Settings › General › Access › "Remove access key" clears both and restarts at the key screen.
- Every build has the gate. The owner's Mac skips it with `defaults write com.pratik.allset accessGateOff -bool YES` (kept on that Mac, not in the app, so any copy sent to someone still asks; `defaults delete com.pratik.allset accessGateOff` brings it back). `ALLSET_ACCESS_GATE=0` in the process's environment also skips it. A debug build without a built-in library skips it too, so tests, probes and CI are unchanged. Once library files need a token, a Mac that skips the gate has none: enter a key there too.
- The private-server command `AllSet library <key>` still runs without the gate (it never opens the app).

Checking a key against the live server once it's up, with the gated app:

```sh
ALLSET_PUBLIC_LIBRARY_URL=https://wallpapers.oddmunks.com ./scripts/build-app.sh
osascript -e 'tell application id "com.pratik.allset" to quit'; open build/AllSet.app
# or from Terminal, without the app:
curl -s -X POST https://wallpapers.oddmunks.com/api/activate -H 'Content-Type: application/json' -d '{"key":"ALLSET-…"}'
curl -s https://wallpapers.oddmunks.com/api/me -H "Authorization: Bearer <token>"
```

To start again from the key screen without the Settings button: `security delete-generic-password -s com.pratik.allset.access -a session; security delete-generic-password -s com.pratik.allset.access -a access-key`.
