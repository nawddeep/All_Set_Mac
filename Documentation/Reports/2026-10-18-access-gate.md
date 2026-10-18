# 2026-10-18 — Access key gate

Branch `feat/access-gate` (from `feat/supplied-funky-themes`), not pushed.

## What changed
- `Sources/AllSetCore/Access/AccessGate.swift`: the state machine (locked, checking, unlocked, offline-unlocked) against `api/activate` and `api/me`.
- `Sources/AllSetCore/Access/AccessVault.swift`: key and token in the Keychain (`com.pratik.allset.access`).
- `Sources/AllSetCore/Access/LibraryAuthorization.swift`: the one place the token is added to requests for the library's host, and where its 401s are reported. `libraryRequest` (store downloads, HEAD checks, free-up-space checks) and `LibrarySync` (catalog, files) go through it.
- `Sources/AllSet/Access/`: `AccessController` (the gate around launch, network watching, restart on a revoked key), `AccessKeyWindow` (the key screen), `LibraryAsset` (AVURLAsset with the token header; dormant today, every wallpaper plays from a downloaded file).
- `AppDelegate`: everything after the DEBUG harness runs only once unlocked. `AllSetApp`: no menu bar item, and the app's commands are disabled, while locked. `AppServices.openWindow` shows the key screen while locked.
- `AccessSettings` on the General page: Remove access key.
- `WallpaperConfig.libraryAddress`: nothing saved, or the retired `100.x.x.x:8080`, becomes the public library, also on a Mac with its own library.
- `scripts/build-app.sh`: `ALLSET_ACCESS_GATE=0` writes `AllSetAccessGate = false`, with a warning.

## Checked
- 490 tests pass (19 new: `AccessGateTests`, `LibraryAuthorizationTests`, `KeychainAccessVaultTests`, one in `LibrarySyncTests`), 0 warnings, hygiene and localization checks pass.
- A gated release build shows only the key window (screenshot looked at), nothing else starts. Typing a key into it wasn't tried from the session (no keyboard control here).
- The server today: `/api/me` 404, `/api/activate` 405, `catalog.json` 200 without a token. A gated app would show "Can't reach the server" until it's live.

## Assumed (not in the contract)
- Keys are sent with all whitespace removed, not just trimmed.
- A 200 from `api/activate` without a token counts as no answer. A missing `expiresAt` means 90 days from now; `name` may be missing.
- Any other status (403, 5xx) from `api/activate` shows the server's `error` text if it sent one, else "Can't reach the server"; 403 means invalid.
- `api/me` answering 429 or 5xx is treated like no answer (offline rule); re-activation answering 429 after a 401 from `/me` is offline mode, not a lock.
- A file 401 renews at most once a minute; the server's root (reachability HEAD) never triggers renewal.
