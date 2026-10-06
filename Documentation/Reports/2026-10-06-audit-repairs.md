# Audit repairs, 2026-10-06

Repairs from the independent audit of 6 October, in its suggested order. Local commits only (git initialised this session; nothing pushed).

## Done
| Phase | Audit # | What changed | Verified by |
|---|---|---|---|
| 1 Layouts | 1, 2 | Picking a wallpaper keeps widgets. A theme preview is written to `desktop-preview.json` before the desktop changes, reverted on quit, restored at launch after a crash. Every whole-desktop change keeps `previous-desktop.json`; Widgets › Restore Previous Desktop. | `DesktopJournalTests` (4) |
| 2 Delete/offload (app) | 10, 13 | Delete Everywhere asks the server first; local copy removed only on 200/404; `pending-deletes.json`; failures delete nothing and retry works. Offload frees a file only if the server copy has the same SHA-256 (downloaded and hashed), after `offloaded.json` is written and read back. | `WallpaperLibraryTests` (retry, 404, same-size different content, unrecordable offload) |
| 2 Delete (server) | 11, 12, 15 | `delete_service.py` decides files from the id (`<folder>/<id>.*` + unshared DB keys), ignores request paths, stages through `.trash/<id>/`, restores on database failure, settles quarantines at startup, bounds requests. | `test_delete_service.py` (11, real Postgres) |
| 2 Catalog API | 15, 16, 17 | Only `published` listed/served unless `--include-quarantined`; binds the Tailscale address (or `--host`); psql timeouts, 503s, Range/206. | `test_catalog_service.py` (6) |
| 3 Catalog sync | 14 | Storage keys left out of the upsert; CSV line endings fixed (COPY failed on psql 17). | `test_sync_catalog.py` (3); reproduced `After|||` first |
| 4 UI | 5, 6, 7, 8, 9 | ⌘1–⌘5 in `CinemaNavigation`; weather from an existing city or the time zone, not London; calendar on the desktop shows events; Delete offers Remove Download / Delete Everywhere everywhere, filter renamed On This Mac; tiles keyboard/VoiceOver-usable (`KeyboardActivatable`); Trending/Popular shown as Recommended/Top Picks. | Build; `-renderPages -pages wallpaper,themes` |
| 5 Release | 22, 24, 25 | Missing TCC symbol → `.unverifiable`, not authorized; render harness fails on a partial set (`render-report.txt`); probe `pipefail`; CI job for server tests; personal server address out of `Info.plist` (build-app.sh injects it from `ALLSET_LIBRARY_SERVER_HOST` / `scripts/local.env`). | build-app.sh run + PlistBuddy |
| 6 Cleanup | 26 | Removed unused `FloatingNav` (and its private helpers) and `ClassicGalleryPage`. | Build, tests |

Totals at the end: 353 Swift tests, 20 server tests, 0 warnings.

## Not done (needs a decision or more than a code change)
- **#3, #4 navigation and visual hierarchy**: a product redesign of the Desktop section; not attempted without design direction.
- **#18, #20 coordinator and narrower dependencies**: only the durable desktop journal was added; AppServices and WidgetOptions were not restructured.
- **#19 stable display identity**: fixed in an earlier session, but that work was lost when the folder was replaced; not redone here.
- **#21 clipboard history default**: a privacy default change; not changed.
- **#23 app-level integration tests** (quit during a preview, end to end): core-level tests only.
- **#25 notarisation pipeline**: needs a Developer ID; not set up.

## Operational notes
- After restarting `catalog_service.py`, a tester sees only published wallpapers: the library is all quarantined, so start it with `--include-quarantined` to keep the current behaviour for your own tester.
- `delete_service.py` now ignores `paths`; older app builds still work against it.
- Server tests: `/usr/bin/python3 -m unittest scripts/cloud/test_*.py` (needs `brew install postgresql@17`).

## Comprehensive review (2026-10-06): status register

Findings from `2026-10-06-comprehensive-review.md`. Every fixed item has a test that failed (or would fail) on the earlier code.

| # | Finding | Status | Commit |
|---|---|---|---|
| R1 | Redaction not authoritative | Fixed | `7616c7f` |
| R2 | AI answer lands in the wrong screenshot | Fixed (late reply dropped; the request itself isn't cancelled) | `3734315` |
| R3 | Audio gain data race | Fixed (atomic helpers; ThreadSanitizer clean) | `8f91b43` |
| R4 | Shelf ownership by string prefix | Fixed (`ContainedPath`) | `4ead711` |
| R5 | Local wallpaper delete escapes the library | Fixed (rejected at load and at every delete/write) | `4ead711` |
| R6 | Server deletes a file another row uses | Fixed | `59f5d70` |
| R7 | Rollback discards an original on collision | Fixed (kept as a conflict) | `59f5d70` |
| R8 | Preview journal retired without confirmed save | Fixed | `9df2319` |
| R9 | Unreadable importer catalog triggers cleanup | Fixed (stops; cleanup moves to `.orphans/`) | `5c9ec48` |
| D1 | Clipboard history on by default | Fixed, see "Remaining gaps" below (`44a1d36`) | `44a1d36` |
| D2 | Pending capture after Clear/Turn Off | Fixed | `d84af1e` |
| D3 | GitHub cache not scoped to credential | Fixed (token fingerprint; external Keychain edits not detected) | `0a922e1` |
| D4 | Key replacement deletes first | Fixed (failure path verified by reading, not by test) | `48e612f` |
| D5 | Unreadable widgets erased by save | Fixed | `ea52076` |
| D6 | Inconsistent save-failure semantics | Fixed for user data: local delete, Notes, widgets, clipboard, shelf, workspaces and wallpaper settings each expose `saveError` until a save works; the main window lists them in one banner with Try Again. Still open: the review's export/restore backup format (a feature, not a fix) | `1b323e2`, see log |
| P2 | Screenshot history by count only | Fixed (600 MB byte budget) | `3734315` |
| P1 | Focus-timer completion owned by a view | Fixed (`FocusTimerCoordinator` in AppServices) | see log |
| P7 | Command timeout not an upper bound | Fixed (TERM, then KILL; bounded drain and output; task cancellation) | see log |
| P5 | Weather/GitHub retried every minute after failures; fetches outlived their widgets; stale data hidden | Fixed (`RetryBackoff` per key and credential, 401 waits longest; `SharedRequests` cancels a fetch once every waiting widget left; forecast and air errors kept apart; `WidgetStaleBadge` shows age and why) | see log |
| P6 | Status check identity lowercased whole URL | Fixed (only scheme and host fold case; path and query keep theirs) | see log |
| P4 | 20 Hz pointer timer ran with no widgets or all covered | Fixed (`NeededTimer`: scheduled only while a widget is shown uncovered; not hand-measured) | see log |
| P3 | Image import on main, thumbnails via full decode | Fixed (import off main, 4 at a time, progress + Stop on My Photos, cancellable; small copies and the wallpaper file skip the full decode). Still open: a quota for the downloaded-photo cache, which needs to know which photos the wallpaper and widgets still use | see log |
| U3 | Toggles exposed by their explanation; unnamed icon buttons | Fixed (`SettingToggle`: name as label, explanation as hint, 9 sites; 10 icon-only buttons labelled). Not checked with VoiceOver running; contrast/Reduce Transparency matrix not done | see log |
| U4 | Notes removed for good | Fixed (Undo for remove, Clear Done and edit-to-empty, in place; Clear Done shows its count; pencil and Edit menu, VoiceOver actions) | see log |
| U5 | "On your server" without checking | Fixed (`copyLocation`: checked on server only when freed after a hash match; otherwise "to download from your server (not checked)") | see log |
| U6 | Copy promising more than the code | Fixed (Monitor keeps sampling slower; About; On This Mac help) | see log |
| U1, U2 | Navigation redesign; compact utility pages | Done in a contained form, see "Remaining gaps" below (`25a120d`) | `25a120d` |
| A1 | AppServices reached through for everything | Addressed where the review asked first: narrow owners at each failure boundary (`FocusTimerCoordinator`, `SharedRequests`/`RetryBackoff`, `CommandRunner`, `ScreenshotStudio` in Core, per-store `saveError`, `WorkspaceRestoreReport`). No wider refactor, as the review advised against one | see log |
| A2 | Workspace restore silent about failures | Fixed (`WorkspaceRestoreReport` per app; moves verified by reading the frame back; hide-others skipped when nothing placed; card shows it; layout-not-documents wording; 1 s AX timeout per window). Not run against real apps | see log |
| A3 | Display identity by name; snap target per zone only; native tiling assumed on macOS 14 | Fixed again (`DisplayIdentity`: display UUID first, name fallback; widgets, workspaces, per-display size and saved wallpapers; wallpaper windows per display; snap target includes the display; native tiling only from macOS 15). Not tried with two identical monitors | see log |
| A4 | Private integrations not release-tested | **Open: needs a test matrix** (lowest supported macOS 14.2, Intel if supported, permissions denied/revoked). Can't be done on this one Mac | |
| O1 | Backend is a personal deployment; tunnel check too weak | Partly: `tunnel.sh --check` requires both ports held by ssh and the delete service answering; ssh exits on a failed forward. `Documentation/operations.md` records the one deployment, health checks and token rotation. **Not set up (listed there): supervision of the delete and catalog services, backups, a restore drill, versioned migrations, catalog pagination** | see log |
| O2 | Tests weak at product boundaries | Addressed per fix: each failure sequence the review named now has a test (redaction R1, screenshot generations R2, journal retirement R8, clipboard capture D2, focus timer P1), plus fetch ownership, import cancellation and hostile import files. The app target itself still has no unit tests; anything only it does (windows, Accessibility, VoiceOver) is unverified here | see log |
| O3 | CI gathers numbers without enforcing them | Partly: the probe job fails past `scripts/probe-budgets.json` or when a measurement is missing. Ceilings are wide (no CI baseline was available) and need tightening from real runs. No visual baselines, no packaged-release job, one macOS generation | see log |
| O4 | Release process not ready for distribution | Partly: packages carry third-party notices, a build number from git, and a verified signature. **Needs an Apple Developer account: Developer ID signing, notarization, updates/rollback, clean-machine install check** | see log |
| O5 | Docs are a history log | Partly: README states the product and points here and to operations.md; README no longer lists retired Aerial videos; architecture.md matches the current offload check, server counts and delete flow. No supported-feature matrix or release checklist yet | see log |
| O6 | Import tooling trusts corrupt input | Fixed (scene.pkg and wetex bounds-checked, loose files contained, every tool call has a deadline, unique temporary names, a library lock). The old wetex crashed on a truncated file and a cut-off LZ4 match | see log |

## Recheck (2026-10-06, `Documentation/Reports/2026-10-06-recheck.md`): status

The recheck reviewed `e94e675` and found four defects still open. Two were introduced by repairs above (S2 in the P7 rewrite, S3 in the R4/R5 helper), and two were repairs that fixed the named case but not the wider one (S1 after R6, S4 after R2). The rows above for R2, R4, R6 and P7 describe what was done at the time; this table is the current state.

| Finding | What was still wrong | Status | Commit |
|---|---|---|---|
| S1 | A reference written during or after a server delete lost its file | Partly at `ad11d88`, completed by T1 below (the retirement's own final purge had the same gap). As first done: the row delete and the shared-file check are one transaction under a lock every catalog writer takes (`catalog_lock.py`, also taken by `sync_catalog.py`); deleted files are retired for 7 days and put back if any row references them. Server disk space is freed a week after a delete. The upload step that writes storage keys is outside this repository and must follow the lock rule | `ad11d88` |
| S2 | Cancelling a command only sent TERM and waited without limit; a timeout left the command's children running | Fixed: the command runs in its own process group; cancel and timeout share one TERM-then-KILL stop for the whole group; the error-output reader can be told to stop | `10e9b96` |
| S3 | Every containment check leaked two path buffers | Fixed: resolves into a temporary buffer; heap growth measured at zero | `84a5a43` |
| S4 | A replaced screenshot's request ran on; nothing checked the document before submitting; closing released nothing | Fixed: the studio owns and cancels its request; checked again before submission; closing keeps only the current picture; pictures over 8,192 px a side are scaled as they open; Stop button. The window-close hook and Stop button are app-target code, not exercised by tests | `64c9158` |

Still open from the recheck's last section, unchanged: navigation and utility-page design (U1, U2), clipboard collection on by default (D1), no user-data export or downloaded-photo quota, no server backup or rehearsed restore, services started by hand, no versioned migrations or catalog pagination, and the release checks (real-app workspace restore, identical monitors, minimum macOS, permission revocation, VoiceOver, Developer ID and notarization, clean-machine install).

ThreadSanitizer has not been run on the recheck fixes, by the recheck or by this work (R3's earlier run predates them).

## Second recheck (2026-10-06, `Documentation/Reports/2026-10-06-recheck-2.md`): status

The second recheck reviewed `b03ca3d`. It accepted S2, S3 and S4 as repaired, called S1 partial, and found the new heap test unreliable.

| Finding | What was still wrong | Status | Commit |
|---|---|---|---|
| T1 | The purge of expired retired files asked "is it referenced?" and then removed, holding no lock: a lock-taking writer could commit a reference in between and be left pointing at a purged file | Fixed for writers that follow both rules: the sweep holds the catalog lock (`AssetLock`, a session of its own) from the question to the removal; `set_storage_key.py` is the supported writer (takes the lock, references only a file in its place, restores a retired one, refuses a missing one). **Limit, by design and documented:** a writer that skips the lock or the file check, such as an `UPDATE` typed into psql, is covered only while the file is still retired; a reference it writes at or after the final purge points at nothing | `89a8747` |
| T2 | The heap-growth test sampled the whole process and failed on unchanged code (1 full run in 12 here) | Fixed: the leak's cause is now checked deterministically through an injectable `realpath`. Running the suite repeatedly found two more unreliable tests, also fixed: one of this work's screenshot tests raced real preparation (now gated through an injectable `prepare`), and the system-monitor test waited a fixed half second. 0 failures in 40 consecutive full runs | `e8cab51` |

Limits the second recheck noted on the accepted repairs, unchanged:

- S2: a descendant that deliberately moves to another process group or session is not stopped with the command.
- S4: preparation and rendering that have already started off the main actor run to their end before the result is dropped; the history figure is a budget for undo pixels, not a ceiling on the process's memory; the window-close hook and Stop button were reviewed in source, not exercised in the UI.

Nothing sets storage keys automatically after `push_wallpapers.sh`; `set_storage_key.py` sets one key at a time by hand.

## Remaining gaps (2026-10-06): the "unchanged product/release gaps" both rechecks listed

The owner asked for these to be completed with judgment, including the ones that had been waiting on a decision. The rows above for D1, D6, P3, U1/U2 and O1 describe the state before this pass; this table is current.

| Gap | What was done | What it does not cover | Commit |
|---|---|---|---|
| Clipboard collection on by default (D1) | A new install collects nothing until its owner turns history on, from a first-run panel that says what is saved, where and for how long. An existing install keeps what it had. Unpinned items expire (30 days for a new install; off for an existing one until chosen). Erase Everything removes pins and pictures too | History is still an unencrypted file | `44a1d36` |
| User-data export and restore (D6) | `DataArchive`: a folder with a manifest of checksums, the preferences and the data. Restore is verified, staged, applied at launch before any store reads, keeps what it replaces, and undoes a failed swap. In General › Back up and restore | Keychain secrets are never exported. The restart and launch alert are app-target code that has not been run | `9a95a8b` |
| Downloaded-photo cache quota (P3) | 1 GB, least recently used first; a photo the wallpaper or a widget shows is never evicted, and nothing is evicted until the app has said what is in use | | `254b58b` |
| Navigation (U1) | Desktop: seven pills to four. Favorites, Wallpaper Options and Look & Layout are opened from the page they belong to, light its pill, and are still found by search. `AppPage`, deep links and shortcuts unchanged. Checked by rendering the pages | A contained regrouping, not a redesign of the whole window; the other four sections are as they were | `25a120d` |
| Utility-page presentation (U2) | AI Screenshot: actions in the header, decorative panel removed, shortcut and examples in the first screen. Checked by rendering the page | Themes and Wallpaper keep their browsing imagery (the review said to keep it for discovery) | `25a120d` |
| Server backups and restore drill (O1) | `backup.py`: dump, hard-linked copy of storage, checksum manifest; `drill` restores into scratch copies and verifies; `restore` is the same code and never overwrites | **Not yet run on the real server.** No off-site copy, no alert when a drill fails | `19899da` |
| Service supervision (O1) | `install_services.py`: launch agents that keep the delete and catalog services running and run a nightly backup plus drill | **Not yet installed on the real server.** Runs only while that account is logged in | `19899da` |
| Versioned migrations (O1) | `migrations/0001_initial.sql`, `migrate.py`, `schema_migrations`; a failing step rolls back; an existing database is adopted | **Not yet run on the real database** | `19899da` |
| Catalog pagination (O1) | `?limit=&offset=` with count and next-offset headers; plain `/catalog` unchanged; at most 8 requests at once | Still one `psql` per request | `19899da` |
| ThreadSanitizer | `swift test --sanitize=thread` reports no data race. One test fails under it for an unrelated reason: the media helper built with the sanitizer can't be loaded into the system's `perl` | Tests only, not the running app | (no change needed) |

Still open, and not something that can be done from this Mac or without the owner:

- **A4 and release checks:** the minimum supported macOS, a second (and an identical) monitor, permissions denied or revoked, VoiceOver with the app running, contrast and Reduce Transparency, a clean-machine install.
- **Distribution (O4):** Developer ID signing, notarization, and updates need an Apple Developer account.
- **The server setup itself:** the four commands in `operations.md`, run on the server.
- **CI performance ceilings (O3):** set wide; they need tightening from real runs.
- **Hand-testing:** the pages changed in this pass were looked at through the debug page renderer. Nothing has been clicked through in the running app.


## Backup/restore safety fixes after the latest review

- Restore rollback now checks every move/removal. If putting originals back fails, their recovery folder stays on disk and the launch alert reports partial restoration with its location. Recovery folders are no longer automatically pruned; remove unwanted copies manually after checking them. Unique names prevent two restores in the same second from sharing a recovery folder.
- Server retention runs a restore drill before pruning any older backup. A failed or unavailable drill leaves older copies untouched. `--keep 0` disables pruning; `--drill` still requests validation in that mode.
- Archive format 2 checksums `settings.plist`, validates its dictionary structure, rejects unlisted data files, symlinks, duplicate/noncanonical paths and unsupported filesystem entries. Settings are read before live data changes. Format 1 lacks the settings integrity record and is refused with instructions to export a fresh backup.
- Regression coverage forces both swap and rollback failures, verifies recovery copies survive later restores, corrupts settings and injects unlisted files, and simulates deletion between the server dump and file copy with `--keep 1`.

Validation: `swift test` passed 432 tests in 100 suites; the server unittest suite passed 52 tests; `swift build -c release` passed without warning/error diagnostics. Real-server deployment and the running-app restart/alert remain outside this verification.
