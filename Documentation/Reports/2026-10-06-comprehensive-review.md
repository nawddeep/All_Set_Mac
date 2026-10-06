# Comprehensive current-state review — 6 October 2026

## Verdict

All Set is a substantial native Mac application with an ambitious visual direction and real implementation. It is still an ambitious beta, rather than a dependable release for ordinary users. Its biggest weakness is the gap between the number of features and the guarantees around their files, requests, recovery, privacy and resource use.

The UI increasingly looks like a finished product. Several underlying operations still behave like developer tools. Stop expanding the feature list until deletion, redaction, recovery and lifecycle ownership are reliable.

This report supersedes the *status* of the earlier audits, not their historical evidence. The first audit's many fixed issues must not be presented as still open. The second audit's six reproduced defects remain present in the source checked for this pass.

## Scope and evidence

Reviewed the Swift application and core, Python wallpaper services and importer boundaries, persistence, permissions, image loading, process execution, CI, build packaging and documentation. Inspected the running app's updated navigation, Themes, Wallpaper, AI Screenshot, Monitor, General and accessibility tree, alongside the earlier visual review. No application-source fixes, settings changes, real AI requests, production-server operations, or deletion of user files were performed. The app bundle changed externally near the end of inspection; findings describe the source snapshot inspected, and the app was returned to its original Island page.

Current checks:

- **353 Swift tests in 87 suites passed.** Test execution took approximately 2.83 seconds after building.
- **20 Python server tests passed**, against disposable local Postgres instances, in approximately 12.96 seconds. The output includes an unclosed-file ResourceWarning in sync_catalog.py; it was not a test failure.
- A new **real disposable-Postgres reproduction** confirmed a surviving wallpaper row loses its shared playback file when another wallpaper is deleted.
- A new **temporary-files reproduction** confirmed rollback discards a quarantined original on a destination collision.
- A new **importer recovery reproduction** with scanner/scene stubs and disposable assets confirmed unreadable-catalog fallback deletes another root’s asset without preserving the damaged catalog.
- An isolated build of the unchanged **CommandRunner** returned after approximately 3.01 seconds for a declared 0.1-second timeout.
- Earlier isolated checks confirmed redaction/blur failure, stale screenshot replacement, a ThreadSanitizer gain race, two local path-deletion defects and status-key collisions. Relevant code remains unchanged in substance.

“Reproduced” below distinguishes executable evidence from source reasoning. This is a review of major subsystems, not a claim that every line, device, OS version, live API or deployment was exercised. No Intel/macOS 14 hardware matrix, production restore drill, sustained battery benchmark or live model-contract test was performed. **Release compilation also passed with zero warnings** (`swift build -c release`, approximately 168.77 seconds). This verifies compilation, not signing/notarization or installation on a clean machine.

## Improvements since the first audit

[Repair record](/Users/nawdddep/Downloads/all-set-mac-app-main/Documentation/Reports/2026-10-06-audit-repairs.md), with corresponding implementation inspected:

- Picking a wallpaper now preserves widgets.
- Theme previews have a durable snapshot and quit/startup recovery path.
- Delete Everywhere contacts the server before removing the local entry; failed requests remain retryable.
- Offloading now downloads and hashes the server copy and verifies a written offload record before removal.
- The server ignores client-supplied paths and stages deletion through quarantine.
- Catalog sync preserves storage keys; the catalog API defaults to published items and a Tailscale interface.
- Request sizes and database waits are bounded; download Range support exists.
- Navigation shortcuts, city selection, calendar behavior and library keyboard access were improved. Recommended/Top Picks replaces misleading popularity labels.
- Partial screenshot renders now fail CI; probe failures are no longer hidden by tee; server tests are in CI.
- Old navigation/gallery implementations were removed and the personal server address was removed from the source Info.plist.

These are meaningful repairs. They do not close the edge cases below.

## Release-blocking correctness problems

### R1 — P1: Redaction is not authoritative

**Reproduced.** [ScreenshotEdit.swift:119](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/AI/ScreenshotEdit.swift:119) blurs the original source image, then paints that result over the current edited context. A blur overlapping a previous black redaction restores original-derived pixels. In the probe a black center pixel became white again. That proves the mask disappeared, not that every blurred secret is readable.

Retain an authoritative redaction mask and apply it last, or ensure subsequent edits cannot read original pixels from protected areas. Add a regression spanning several AI requests, not only edits in one request.

### R2 — P1: A request can complete into the wrong screenshot document

**Reproduced.** [ScreenshotStudio.swift:71](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Screenshot/ScreenshotStudio.swift:71) captures state, awaits AI work and pushes the old state after [load:59](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Screenshot/ScreenshotStudio.swift:59) has replaced the document. New Screenshot and Open remain available. The delayed-mock probe changed the new image's width from 128 back to the old 64.

Give the document a generation ID; cancel and invalidate outstanding work on replacement. Both success and error replies must belong to the originating document.

### R3 — P1: Audio gain crosses threads without synchronization

**Reproduced with ThreadSanitizer.** [GainBox:23](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Audio/AppAudioTap.swift:23) marks itself unchecked Sendable while a plain Float pointer is written by UI code and read by the audio callback. A naturally sized load/store is not the required synchronization.

Use an actual lock-free atomic representation or an audio-safe parameter handoff. Avoid blocking the real-time callback. Also test rapid volume changes while routes are rebuilt.

### R4 — P1: Shelf ownership is inferred from a string prefix

**Reproduced.** [ShelfStore.swift:60](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Clipboard/ShelfStore.swift:60) treats a sibling path such as `Shelf/Dropped-Other/file.txt` as shelf-owned because it starts with the characters `Shelf/Dropped`. Removing the entry deleted that external disposable file.

Record ownership explicitly, check canonical path components and define a symlink policy. A shelf that promises to remember an external file must not accidentally own its deletion.

### R5 — P1: Local wallpaper deletion has no containment boundary

**Reproduced.** [deleteLibraryVideo](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Wallpaper/WallpaperStore.swift:631) appends catalog paths and deletes them without resolved containment validation. A catalog playback path `../outside.txt` deleted a file outside Library. This is a local/imported-catalog trust defect; no unauthenticated remote exploit was established.

Reject escaping paths at ingestion and at every read/write/delete boundary. Use the same validated path type throughout downloading, offloading and deletion.

### R6 — P1: The repaired server still deletes a shared asset

**New; reproduced with real disposable Postgres.** [owned_files:125](/Users/nawdddep/Downloads/all-set-mac-app-main/scripts/cloud/delete_service.py:125) unconditionally collects `<folder>/<id>.<ext>` files. Only the subsequent database-key branch checks `key_used_elsewhere`. The filename branch bypasses that protection.

Probe: rows A and B both referenced `live/a.mp4`. Deleting A returned 200; B's row and playback key survived, but the file was gone. Apply reference checks to every candidate, including filename matches. Make the reference check and database mutation consistent under concurrent metadata changes.

### R7 — P1: Rollback silently destroys its own original on conflict

**New; reproduced with disposable files.** [restore_quarantine:148](/Users/nawdddep/Downloads/all-set-mac-app-main/scripts/cloud/delete_service.py:148) skips a held file if its destination already exists, then removes the entire quarantine. If an importer/upload recreates that path while deletion is staged, a failed delete discards the original backup and retains the replacement.

Keep unresolved originals and report a conflict. A rollback must not turn an ambiguous collision into irreversible cleanup. Add fault-injection tests for destination recreation and restore failures.

### R8 — P1: Preview recovery clears its journal without confirming persistence

**New; source-backed.** [recoverInterruptedPreview:114](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/AppServices+Themes.swift:114) restores in memory, invokes WidgetStore.saveNow and removes the preview journal regardless of `widgets.saveError`. Go Back uses the same sequence. If layout saving fails while journal removal succeeds, recovery loses the durable before-state and still says the desktop is back.

[recordChange:141](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/AppServices+Themes.swift:141) and Restore Previous Desktop also ignore DesktopJournal.remember's Boolean. [endPreview:62](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Themes/DesktopJournal.swift:62) ignores removal errors; a retained journal can roll back a preview the user chose to keep on the next launch.

The journal is a good start. Finish the transaction: explicit persistence results, a committed state, verifiable restoration and journal retirement only after success. Retain a retryable record on failure. Tests currently establish core journal behavior, not this application-level failure sequence.

### R9 — P1: An unreadable importer catalog triggers destructive cleanup

**New; reproduced using the actual importer control flow with scanning/scene stubs and disposable files.** [import_library:1509](/Users/nawdddep/Downloads/all-set-mac-app-main/scripts/wallpaper_library.py:1509) treats both a missing catalog and an existing unreadable catalog as a fresh empty library. After importing one root, it writes that replacement and calls [clean_orphans:1473](/Users/nawdddep/Downloads/all-set-mac-app-main/scripts/wallpaper_library.py:1473), which permanently removes files not referenced by that catalog from all managed asset folders.

Probe: an unreadable catalog, an empty scanned root and an existing video belonging to another root. Import completed, wrote an empty-item replacement catalog, deleted the other root’s video and preserved no copy of the damaged catalog. Scanner/renderer stubs removed unrelated tool dependencies; the catalog fallback, writing and cleanup were real.

Distinguish first-run absence from read/decode failure. Preserve the original and abort cleanup unless the full reference inventory is valid. Stage cleanup through recoverable trash and protect the catalog/asset transaction from concurrent writers.

## UI and UX

### U1 — P2: Navigation exposes the implementation's compartments

**Observed and source-backed.** [AppNavigation](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Design/AppNavigation.swift:77) offers seven Desktop destinations, followed by theme filters and more horizontally arranged rails. Themes, Widgets, Look & Layout and On Your Desktop require a user to infer where creation, appearance and management differ. Wallpaper and Wallpaper Options split another task. Favorites appears both as a destination and a theme filter.

Organize around three jobs: discover a look, customize the current desktop, and manage installed/downloaded items. Place settings next to the object they control. Preserve direct links and shortcuts while reducing top-level choices. Changing labels alone will not solve the hierarchy.

### U2 — P3: Utility screens spend too much space on presentation

**Observed.** AI Screenshot uses a large decorative hero to expose two buttons, pushing shortcut information down. Themes and Wallpaper place substantial browsing imagery and controls ahead of library work. The design rules request calm visual hierarchy, but several pages make decoration as prominent as the work.

Keep cinematic presentation for discovery. Make utility pages compact and action-oriented; bring status, failure recovery and the next useful action into the first viewport. Theme previews did finish loading during this pass, so the initial spinners are not reported as a permanent failure.

### U3 — P2: Several settings have misleading accessibility names

**Observed in the accessibility tree.** On General, the visible setting “Show All Set in the Dock” was exposed using its explanatory paragraph. Clipboard's enable switch was exposed as “Stored only on this Mac.” [SettingsView](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Settings/SettingsView.swift:42) and [ClipboardPages](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Clipboard/ClipboardPages.swift) use multi-Text toggle labels.

Supply an explicit setting name and separate hint. Audit sliders, icon-only actions, note editing and hover-only controls with keyboard and VoiceOver. The improved wallpaper tiles do not prove accessibility across the rest of the app. Contrast and Reduce Transparency adaptation also need a deliberate test matrix; no accessibility certification is claimed here.

### U4 — P2: Notes have permanent removal without recovery

**New; source-backed.** [NotesViews.swift:120](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Notes/NotesViews.swift:120) removes individual notes from a hover action; Clear Done removes the completed group immediately. [NotesStore:62](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Notes/NotesStore.swift:62) saves the reduced list without trash/history or an undo transaction. Editing a note to empty also removes it.

Provide undo or a short-lived trash/recovery mechanism. Bulk cleanup should show how many notes are affected. Use actual controls for editing rather than a text tap gesture as the only obvious entry.

### U5 — P2: Server availability is presented as verified storage

**New; source-backed and visible wording observed.** [WallpaperPages.swift:324](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Wallpaper/WallpaperPages.swift:324) calls items “on your server” solely because they are missing locally, a server URL is configured and an asset path exists in metadata. It does not confirm those remote files exist. Reachability of the server root is not per-file inventory verification.

Show “requires download” or “expected on server” until inventory/hash evidence confirms a copy. Distinguish verified availability from configuration. A user should not infer backup safety from that count.

### U6 — P3: Some product copy promises more than the code does

**New; observed/source-backed.** Monitor says “nothing here runs once the window closes”, while [SystemMonitor](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/System/SystemMonitor.swift:5) intentionally continues inexpensive sampling at an idle interval and other viewers can keep detailed sampling active. About still describes only a Dynamic Island and system monitor despite the wider product. The On This Mac filter's help text also retains the old claim that deletion there only removes the local copy, while the revised dialog offers separate actions.

Describe actual behavior plainly: slower sampling, cached data, expected remote assets and partial restores. These inconsistencies damage trust even when the underlying policy is reasonable.

## Privacy, persistence and user data

### D1 — P2: Clipboard history starts collecting before a clear first-run choice

[ClipboardSettings:104](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Clipboard/ClipboardStore.swift:104) defaults to enabled, 200 items and no clear-on-quit. [AppDelegate:266](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/AppDelegate.swift:266) starts collection. Text and images are stored locally without an application-level encryption layer. Private pasteboard markers and ignored password-manager apps are useful safeguards, but ordinary copies can still contain secrets.

Use a first-run choice that explains collection and retention. Add time-based expiry, an explicit purge including pinned items and image files, and a discoverable privacy/data page. “Local” describes destination; it does not describe retention or all sensitive-copy risks.

### D2 — P2: Disabling or clearing history does not invalidate pending capture

**New; source-backed.** [ClipboardMonitor:74](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Clipboard/ClipboardMonitor.swift:74) checks permission/settings, starts detached image encoding and later adds the result without checking whether collection was disabled or history cleared meanwhile. A pending capture can repopulate history after the user's action.

Maintain a capture generation and invalidate pending work on disable/clear. Dispose of a completed file if its generation is no longer accepted. Test the sequence with an intentionally delayed encoder.

### D3 — P2: Private GitHub cache is not scoped to the credential

[GitHubService:342](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Developer/GitHub.swift:342) loads JSON snapshots keyed by widget configuration rather than authenticated identity. Token removal/replacement does not clear them. Old private-repository data can remain visible or temporarily appear under a changed account. This is local retention, not evidence of remote access after revocation.

Scope snapshots to account/credential identity, invalidate on changes and expose a cache purge.

### D4 — P2: Credential replacement destroys the old key before success

[AIKeychain:53](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/AI/AIImageEditors.swift:53) and [GitHubKeychain:414](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Developer/GitHub.swift:414) delete before adding. Failure removes the valid prior key. Screenshot key saving simply returns on failure. Update existing items, add only on not-found, and expose actionable errors.

### D5 — P2: Lossy widget loading can silently erase unsupported records

**New; source-backed.** [WidgetStore.swift:132](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Widgets/WidgetStore.swift:132) uses LossyList to skip records it cannot decode. Partial failure does not trigger the unreadable-file preservation path. A later save writes only the accepted records, losing skipped widgets—particularly after downgrades or schema changes.

Preserve the original on partial decode, report skipped records and retain unknown raw entries when practical. Version the persisted schema and test upgrade/downgrade fixtures. Keeping good widgets visible is sensible; silently forgetting the others is not.

### D6 — P2: Persistence has inconsistent failure semantics

WidgetStore exposes saveError in the main window, which is useful. [NotesStore.save](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Notes/NotesStore.swift:103), clipboard, wallpaper and several other stores mainly log failures. [deleteEverywhere](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Wallpaper/WallpaperStore.swift:715) reports success after server confirmation even though local cleanup and pending-record removal can fail silently.

Define explicit save/cleanup results and a consistent dirty/retry state. “Atomic write” protects a single file from partial replacement; it does not make settings, widgets, wallpaper, journal and remote metadata one transaction. Add a coherent export/restore format and exercise restoration from it before promising backup.

## Performance, lifecycle and networking

### P1 — P2: Focus-timer completion belongs to a view

[FocusWidgets:152](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Widgets/Kinds/FocusWidgets.swift:152) and [CinematicWidgetFace:166](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Widgets/Kinds/CinematicWidgetFace.swift:166) finish phases and sound notifications inside SwiftUI tasks. Hiding widgets clears hosting roots in [closeWindow:283](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Widgets/DesktopWidgetController.swift:283), canceling those tasks. Completion is processed when the view returns, and a sufficiently late sound is skipped.

Make a service own timers and phase transitions. Views should render state, not determine whether a timer completes.

### P2 — P2: Screenshot history is bounded by count, not bytes

[ScreenshotStudio:35](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Screenshot/ScreenshotStudio.swift:35) retains up to 25 full-size images. At the source's own roughly 60 MB per 5K image, distinct versions can retain approximately 1.5 GB of pixels before other overhead. This is an estimate, not measured resident memory; shared references can cost less. The singleton retained studio survives window closing.

Use byte-based history limits, reclaim session data when appropriate and integrate with memory-pressure handling.

### P3 — P2: Image import and thumbnail loading do unnecessary work

[importImages:212](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Aesthetics/ImageLibrary.swift:212) decodes/scales/encodes a folder of up to 100 images synchronously on the main actor. Multiple folders compound the workload. [Small-image loading:326](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Aesthetics/ImageLibrary.swift:326) first calls the full-image loader, then decodes a thumbnail and evicts the full image.

Separate download/file availability from decoding. Process imports off-main with bounded concurrency, progress and cancellation; decode the requested thumbnail directly. Memory cache limits are present, but the downloaded photo cache has no comparable eviction/quota policy in this implementation.

### P4 — P3: Unneeded pointer wakeups continue

[DesktopWidgetController:80](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Widgets/DesktopWidgetController.swift:80) schedules a 20 Hz pointer timer even when widgets are hidden or there are no windows. Guards reduce work but do not unschedule wakeups. Enable it only when interaction requires it. No battery-drain percentage was measured.

### P5 — P2: Failure retries and request ownership are weak

[WidgetRefresh:343](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Widgets/Design/WidgetComponents.swift:343) rechecks at least once a minute. Weather/GitHub throttle by successful fetch time; ordinary offline/authentication errors do not establish per-key retry deadlines. GitHub's explicit rate-limit pause is an exception. Services spawn unstructured fetch tasks, so canceling the view loop does not cancel the current request.

Use failure backoff, credential-specific handling and explicit request ownership/cancellation. [WeatherWidget:21](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Widgets/Kinds/WeatherWidget.swift:21) also hides refresh failures whenever old data exists; show last-updated age and a stale/error indicator. Forecast and air-quality errors should not share one slot.

### P6 — P2: Health-check identity changes URL meaning

**Previously reproduced.** [StatusService:99](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Developer/StatusService.swift:99) lowercases the entire address. Case-sensitive paths/query values collide, sharing status and in-flight suppression. Normalize scheme/host, preserve path/query semantics.

### P7 — P2: CommandRunner's timeout is not an upper bound

**New; reproduced.** [CommandRunner:130](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Knock/KnockActionRunner.swift:130) sends terminate, then waits indefinitely for stderr to drain. A process that ignores the signal, or a descendant retaining the pipe, can keep it waiting. Output is also collected without a size cap. The isolated probe with a 0.1-second timeout and a TERM-ignoring child returned after about 3.01 seconds.

Define process-group cancellation, a grace deadline, escalation and bounded output/draining. Swift task cancellation should propagate to the process. Report whether it actually stopped rather than assuming a sent signal achieved that.

## Architecture and platform integration

### A1 — P2: AppServices is the dependency everyone reaches through

[AppServices](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/AppServices.swift:56) owns almost every store and controller; its theme extension adds orchestration and durable state. WidgetOptionsEditor is about 1,640 lines and WidgetModels about 1,463. Size alone is not a defect; the practical problem is that views can reach broad mutable services and lifecycle/business actions are scattered among them.

Introduce narrow interfaces for desktop transactions, file ownership, timer completion, request cancellation and persistence outcomes. Refactor around these failure boundaries first. A blanket rewrite or dependency framework would add risk without necessarily fixing them.

### A2 — P2: Workspace restore cannot reconstruct what it saved

[WorkspaceController:41](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Workspace/WorkspaceController.swift:41) remembers app IDs/titles/frames rather than document identifiers. Missing apps or failed launches are skipped; missing windows are awaited up to approximately eight seconds per app and then omitted. [AXWindow.setFrame:85](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Workspace/Accessibility.swift:85) ignores return codes. Hiding other apps still proceeds.

Return per-app/window results, verify placement, distinguish layout restoration from document restoration and make partial outcomes visible. Synchronous Accessibility calls on the main actor can also stall interaction when a target app is slow.

### A3 — P2: Display identity and snap state are unstable

Layouts, screen fits and original wallpaper maps still use localized display names, which can collide between identical monitors. Persist a stable display identity with sensible migration/fallback.

[WindowManager:168](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Workspace/WindowManager.swift:168) refreshes a drag target only when its zone changes, not when its display changes. Consecutive events in the same zone on different displays retain the old target; no physical reproduction was performed. Include display/frame identity.

[NativeTiling:24](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Workspace/Accessibility.swift:24) defaults an absent preference to enabled, disabling All Set snapping even though macOS 14.2 is supported and the code describes native tiling as 15+. Gate by OS capability; this pass did not run on macOS 14.

### A4 — P2: Private integration risk is documented but not release-tested

The MediaRemote/Apple-signed Perl bridge, private sensor APIs and private audio-authorization probing create platform dependencies. The missing-TCC-symbol behavior was improved to unverifiable, and media failure has explicit UI state. Those are good fallbacks.

Keep adapters and graceful degradation, and test supported OS/hardware combinations and permissions denied/revoked. A successful current-Mac test is not evidence that the lowest supported OS, Intel or future platform changes are handled. No claim about future store approval or API availability is made here.

## Backend operations, tests and distribution

### O1 — P2: The backend remains a personal deployment

The services and scripts use a local Postgres, Tailscale/SSH, manually run processes and machine-specific defaults. [tunnel.sh](/Users/nawdddep/Downloads/all-set-mac-app-main/scripts/cloud/tunnel.sh) tests only the PostgreSQL port when claiming the tunnel is up; it does not establish the delete forward or server identity. A different local Postgres can satisfy that check.

Document one supported deployment, supervision/restart, health checks for each service, token rotation, migrations, backup and a restore drill. Catalog requests still launch psql per request and aggregate the entire list; ThreadingHTTPServer has no bounded application-level concurrency or pagination. These are scalability limits, not evidence that a personal tester already overloads it.

### O2 — P2: Tests are strong on core behavior and weak on product boundaries

Current passing tests include valuable failure checks for deletion, offloading and storage. They did not catch the shared filename, rollback collision, view-owned focus timer, pending clipboard capture or journal retirement sequence.

Add a small integration layer around those failure sequences. Extend schema fixtures, rapid account/document changes, permission revocation and hidden/closed-window cases. Avoid collecting more trivial unit tests merely to raise the count.

### O3 — P2: CI gathers UI/performance evidence without enforcing regressions

[CI](/Users/nawdddep/Downloads/all-set-mac-app-main/.github/workflows/ci.yml) now catches missing renders and failed probes. It still accepts performance numbers without a budget/comparison, and rendered pixels without assertions or a required review. It runs one macOS generation.

Keep artifacts, add stable budgets for measured workloads, selected visual baselines and keyboard/accessibility flows. Separate cold-load and warm-scroll expectations. Validate a packaged release, not only the debug executable.

### O4 — P2: The release process is not ready for ordinary distribution

[build-app.sh](/Users/nawdddep/Downloads/all-set-mac-app-main/scripts/build-app.sh) packages and signs with a local development certificate or ad hoc signing. It does not provide a Developer ID/notarization pipeline, versioned release artifact, update/rollback flow or clean-machine install verification. Info.plist remains version 0.1.0/build 1.

The repo contains Lid Plane notices/license text and attribution, but the packaging script copies only the helper, icon and artwork resources—not the existing third-party notices. Establish a release license/asset inventory and carry notices into the distributed package. This is a packaging/provenance finding, not a legal conclusion about the project's licensing.

### O5 — P3: Documentation is a history log more than a current contract

README, frontend rules, HANDOFF, architecture notes and many dated reports overlap. Architecture notes still describe an earlier stage with no local offload action. Repair status lives in another report; the earlier audits remain easy to read as current defects.

Keep historical reports, but maintain a current architecture/data-flow map, supported-feature matrix, release checklist and issue register with open/fixed/verified status. Align README/About with the intended product promise.

### O6 — P2: Import tooling lacks a consistent hostile/corrupt-input boundary

**Source-backed.** [Package](/Users/nawdddep/Downloads/all-set-mac-app-main/scripts/wallpaper_library.py:274) accepts archive counts, offsets and lengths without a checked file-bounds model. Loose-file fallback joins requested asset paths without a containment check. [wetex Reader/LZ4](/Users/nawdddep/Downloads/all-set-mac-app-main/scripts/wetex.swift:16) reads slices and match bytes directly and trusts allocation sizes. A truncated LZ4 match can access `source[i + 1]` without ensuring it exists. Texture decoding is a subprocess, which limits direct app impact; this is not evidence of arbitrary code execution.

Scene rendering has a timeout, but several texture/ffmpeg/probe operations do not. Bound input/output sizes, validate offsets and dimensions, return structured per-item errors and apply operation deadlines consistently. Add malformed/truncated asset fixtures. Catalog replacement is atomic, which is good, but shared fixed temporary names and no transaction/locking boundary also make simultaneous imports unsafe.

## Product direction

The strongest coherent proposition is a coordinated desktop with an Island hub: discover a look, apply it safely, customize it and recover it. Clipboard, workspace management, per-app audio, sensor-based gestures, screen folding and AI editing each add their own permissions, failure modes and support burden. They are not free additions just because they fit under Tools.

Choose which features must be dependable at release and label the rest experimental or defer them. Do not add an account system, cloud stack or telemetry simply to make the project look more “complete”; none is required to repair the defects here. The product needs a clearer first useful action, a discoverable privacy/permissions/data page and an honest status for partial/offline outcomes.

## Recommended work order and acceptance criteria

1. **File/redaction safety:** repair R1–R7 and R9; tests must prove later edits cannot reintroduce redacted pixels and every deletion candidate is owned, unshared and recoverable on failure.
2. **Transaction completion:** repair R8 and D5/D6. Inject failed writes, failed journal removal, crashes and schema changes; the durable before-state must remain until completion is proven.
3. **Lifecycle ownership:** services own screenshot generations, clipboard captures, timers, fetches and child processes. Hide/close/disable/reload cannot commit stale work.
4. **Privacy and failure UX:** explicit clipboard collection choice, cache purge/identity boundary, save errors, stale indicators and workspace result details.
5. **Resource budgets:** bound screenshot bytes, image concurrency/output, disk cache, background wakeups and network retries; measure representative workloads.
6. **Simplify the UI:** three coherent desktop jobs, compact utility screens, correct accessibility names, visible recovery and fewer competing controls.
7. **Release verification:** packaged builds on the support matrix, production-like backup/restore, notices and signing/notarization/version/update handling.

Ship when the failure sequences pass—not when the catalog has another theme or the test count rises.
