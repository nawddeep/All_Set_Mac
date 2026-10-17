# 2026-10-08 (night): sharing the wallpaper library by API key

## What changed

The evening started by restoring per-person sign-in from `perf-audit` so a friend could use the library. Two people were invited; neither got in, both stopped by Tailscale sharing rather than by sign-in. The user then asked for the simpler route: one permanent, reusable API key and a command.

**App**
- `Sources/AllSet/LibraryCommand.swift`: `AllSet library <key> [--list-only] [--server <address>]`. `Launcher` in `AllSetApp.swift` runs it before the app starts, so nothing opens.
- `Sources/AllSetCore/Wallpaper/LibrarySync.swift`: fetches `<server>/api/library`, saves it as `Library/catalog.json`, downloads pictures (6 at a time) then videos (3 at a time, smallest first), stops before free space falls under 10 GB. Entries whose paths would leave the library folder are dropped. A Mac whose catalog has its own roots is never overwritten.
- `Sources/AllSetCore/Wallpaper/LibraryKey.swift`: the key in the Keychain, and the cross-process notification the command posts.
- `AppServices.startLibrary()`: adopts the built-in server URL when none is set, sends the key with library requests (read from the Keychain at the first request, not at launch), and reloads the library at most once a second while the command runs.
- Removed: `LibraryAccount.swift`, `LibrarySignIn.swift`, their tests, the sign-in gate in `MainWindow` and `WallpaperStore.libraryRejected`.

**Server** (`scripts/cloud/`)
- `catalog_service.py`: the key in `~/.allset_catalog_token` is accepted wherever a session is, including `/me`, which is what Caddy asks before serving a file. New `GET /library`. Sessions and `accounts.py` are unchanged.
- `deploy_catalog.sh`: copies the service to the server, restarts it and checks `200` with the key and `401` without.

## State of the server

The server runs the accounts version started by hand this evening (no key, no `/library`). `deploy_catalog.sh` has not been run. Until it is, the command answers "error (404)".

Accounts on the server: `nawdeepvyas9@gmail.com` (temporary password reissued this evening) and `noreply@technonjr.org` (invited this evening). Both still work after the deploy.

## Checked

- 450 Swift tests pass, 8 of them new (`LibrarySyncTests`).
- 23 server tests pass against a throwaway Postgres 18 (`ALLSET_PG_BIN=/opt/homebrew/opt/postgresql@18/bin`; without it they skip, since `pgtest.py` looks for postgresql@17).
- The built app's `library --help`, a wrong key and an unreachable address all end with the right message and status 1, without touching the Keychain.

## Not checked

- The command against the real server with the real key.
- The running app picking up the notification.
- The dmg on another Mac.

## Open

- The other Mac must reach the server's Tailscale address. That is what stopped both friends. The alternative is Tailscale Funnel, which puts the library on the public internet behind the key alone; `catalog_service.py` says never to do that, and every wallpaper in it is `quarantined` (sharing rights unknown).
- The library is 992 videos, 69 GB. A full download over a home connection takes hours.
- No Developer ID: the other Mac needs `xattr -dr com.apple.quarantine /Applications/AllSet.app` or Open Anyway.
