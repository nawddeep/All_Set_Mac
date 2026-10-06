# Independent project audit — 6 October 2026

## Verdict and scope

All Set has substantial implementation, but its product scope has outrun its recovery model and navigation. The visual work is stronger than the guarantees around user data. I would treat this as an ambitious beta, with the permanent deletion and offloading flows needing repair before broader distribution.

Reviewed Swift UI, controllers, persistence, wallpaper services, Python server scripts, packaging, CI and tests. Visually inspected the running app's Island, Themes, Widgets, Wallpaper and Window Snapping screens. The running binary uses the older navigation/gallery, whereas current source uses CinemaNavigation and GalleryPage in CinematicWidgets.swift. Visual observations about that binary are explicitly distinguished below.

The workspace changed during the review: BatteryReader.swift's first compile error was corrected externally and ZZProbeTests.swift disappeared after the test run. I made no application-source fixes. First swift test failed on an escaping closure capturing a nonescaping parameter. The rerun built successfully and reported **346 tests in 87 suites passed**. This is an observed run, not a guarantee about subsequent edits.

An isolated Python reproduction used temporary files and a mocked failed database operation. It confirmed deletion of an unrelated asset, deletion surviving database failure, and unhandled malformed-payload exceptions. No real catalog, wallpaper or database was deleted. No production backend, other macOS version, full accessibility workflow, or battery/CPU benchmark was exercised.

Priorities: P1 = repair before broader release; P2 = meaningful usability/reliability issue; P3 = maintenance or operational improvement. UI judgments are qualitative, not measured usability results.

## UX and UI

### 1. P1 — Choosing a wallpaper destroys the widget composition

`Sources/AllSet/AppServices+Themes.swift:132` sets the wallpaper, replaces all widgets with an empty array, and resets widget styling. These are independent user intentions, yet a wallpaper selection performs both. The backup lives only in `UIState.desktopUndo`. `Sources/AllSet/Studio/ThemesPage.swift:285` discards wallpaper-clear undo after 12 seconds while its banner is mounted.

Consequence: a user can lose a carefully arranged desktop through an ordinary appearance change, and cannot recover through this undo after timeout or relaunch. Fix: preserve widgets by default; make clearing them a separately named action, and retain a durable previous layout.

### 2. P1 — A temporary theme preview can become permanent on quit

`AppServices+Themes.swift:79` replaces widgets and updates wallpaper/settings using the normal persistent stores. Its rollback snapshot exists only in `UIState.themePreview`. `AppServices.swift:111` saves widgets on stop but does not revert an unaccepted preview; application termination calls that method.

Consequence: quit or crash while previewing, then relaunch, and the trial desktop survives without the original rollback state. Fix: persist a preview transaction before changing the desktop; restore it on startup unless explicitly committed. A normal quit should revert an unaccepted preview.

### 3. P2 — Navigation asks users to learn too many overlapping places

`Design/AppNavigation.swift` defines five top-level sections and seven Desktop pages. Appearance work is spread across Themes, Widgets, Favorites, Wallpaper, Look & Layout, Wallpaper Options and On Your Desktop. In the running app, those page pills sit above another row of content filters.

Consequence: users must understand the app's internal feature taxonomy before finding a simple action. Fix: make browsing and editing the current desktop the two primary Desktop tasks. Put wallpaper options beside the wallpaper and appearance controls in the widget inspector.

### 4. P2 — Visual hierarchy overemphasizes browsing spectacle

Observed running UI: the Themes screen stacks navigation, page pills, category filters, a large carousel, repeated selected-theme metadata and actions before the next shelf. The Gallery shows three large cards per row; card controls approach the bottom of the window. Island places a large demonstration before its settings. Wallpaper gives its current image most of the first viewport.

The artwork is appealing, but the screens make comparison and configuration slower than necessary. Fix: offer a compact gallery, reduce persistent header height, keep the selected item's action beside its preview, and put operational settings closer to the top. Validate at the actual 900×600 minimum window size, not only a large display.

### 5. P2 — Current navigation loses documented conveniences

`MainWindow.swift:168` uses `CinemaNavigation`. Unlike `FloatingNav`, `Design/CinemaDesign.swift:32` has no Command-1 through Command-5 bindings and no visible show/hide or arrange controls. `AllSetApp.swift` still provides widget commands through menus, so those capabilities are not entirely gone.

Consequence: the newer design regresses direct access and disagrees with README's navigation description. Fix: carry these interactions into the active navigation, consolidate the two implementations and update documentation.

### 6. P2 — Weather onboarding silently chooses London

`Studio/CinematicWidgets.swift:58` assigns London to weather instances produced by its factory, including instances passed to Add to Desktop. This is a real widget configuration, not just preview artwork. The same factory disables calendar events at line 50.

Consequence: a working-looking widget can display irrelevant information without explaining setup. Fix: reuse an existing city or ask for one, and distinguish sample preview data from installed configuration. Explain calendar access and event visibility at addition time.

### 7. P2 — Delete changes meaning according to a browsing filter

`Wallpaper/WallpaperPages.swift` chooses offload-only deletion when Owned is selected and permanent server/database deletion otherwise. The confirmation text is helpful, but a filter should not redefine a destructive command.

Fix: offer two explicitly named actions consistently: Remove Download and Delete Everywhere. Rename Owned to Downloaded or On This Mac; file availability is different from ownership or sharing permission.

### 8. P2 — Mouse-only paths remain in library interaction

`WallpaperPages.swift:666` opens a library tile through `onTapGesture`; its delete button is created only on hover or while confirming. `Studio/LibraryPages.swift` also uses tap gestures for image selection. These do not automatically supply the standard focus and activation behavior of a Button.

Consequence: keyboard and assistive-technology users may not reach the same actions. Fix: use semantic controls, retain actions during keyboard focus, and test Tab/Space/Return and VoiceOver. Many existing accessibility labels are useful; the issue is inconsistent interaction semantics.

### 9. P2 — “Trending” and “Popular” imply evidence the app does not have

`AllSetCore/Themes/ThemeStats.swift:65` computes ranking from bundled baselines, local usage and seasonal boosts. There are no community popularity counts in this implementation.

Fix: name these Recommended, Seasonal or Your Favorites unless real aggregate rankings are introduced. Current labels can create misleading social proof.

## Backend, persistence and architecture

### 10. P1 — Failed Delete Everywhere cannot be retried normally

`WallpaperStore.swift:653` obtains the item's paths, then calls `deleteLibraryVideo` before checking the token or contacting the server. That removes the item from memory and catalog. A second call with the same ID returns nil because `libraryVideo(id)` no longer exists. The error UI at `WallpaperPages.swift:615` tells the user to try again anyway.

Fix: retain a durable pending-delete record with ID, paths and stage. Retry that record; remove the local catalog item only when the operation completes or the user explicitly chooses local removal.

### 11. P1 — Server deletion trusts client-supplied file paths

`scripts/cloud/delete_service.py:94` removes paths supplied in the request independently of the requested ID. `safe_path` usefully blocks escapes outside STORAGE, but does not prove a file belongs to that wallpaper.

Confirmed using a temporary file: a request for `different-wallpaper` removed `unrelated.mp4`. This requires the service token; it is not an unauthenticated exploit. Fix: look up storage keys from the database by ID, reject unknown IDs, and account for shared assets before removing files.

### 12. P1 — Filesystem and database deletion can disagree permanently

`delete_service.py:100` removes files before its SQL DELETE. A failed database operation produces 207 while the files are already gone. Conversely, refused file removals do not prevent database deletion. Confirmed the first scenario with a mocked database failure.

Fix: use a durable staged operation with tombstones or quarantine, idempotent retries and reconciliation. A SQL transaction alone cannot roll back an already removed file.

### 13. P1 — Offloading equates equal length with identical content

`WallpaperStore.swift:576` approves removal after an HTTP 200 HEAD response with matching Content-Length. A corrupt or unrelated same-size file passes. The importer contains hash metadata, but this check does not use it.

Fix: require a trusted stored content digest and verified remote copy. Also write the offload journal durably before deletion; `recordOffloaded` runs afterwards and suppresses write errors.

### 14. P1 — Catalog sync wipes storage keys

`scripts/cloud/sync_catalog.py:94` supplies None for playback_key, still_key and thumbnail_key. Line 125 includes these fields in ON CONFLICT updates. Re-syncing an existing uploaded row therefore sets its storage keys to NULL. The catalog API then cannot find its playable file.

Fix: preserve existing asset keys during metadata sync, or provide the actual keys. Keep upload state and descriptive metadata updates separate. This is a code-level finding; the real database was not accessed.

### 15. P2 — Server request handling is insufficiently bounded

`delete_service.py:81` parses Content-Length outside the error handler, has no body size limit, and does not validate each paths element or the top-level object. Temporary reproductions produced AttributeError for a numeric path and TypeError for an array payload. Its single-threaded HTTPServer has no explicit request read deadline.

`catalog_service.py` spawns psql per request, has no subprocess timeout, request concurrency bound or pagination, streams files without Range handling, and suppresses all request logging.

Fix: validate requests completely, cap body size and concurrency, set read/database deadlines, return structured errors and record sanitized operational failures. Long wallpaper downloads should support resumable transfer.

### 16. P2 — Sharing-status rules are not enforced by the catalog service

`WallpaperLibrary.swift` says quarantined files have unknown sharing rights and are never published. `catalog_service.py:66` includes every status except unsupported, and `/file/<id>` does not check published status at all.

Fix: explicitly enforce the declared sharing policy at listing and download. If a tester is allowed to use a personal catalog, model that separate permission rather than dropping provenance and treating every playable item alike. This is a policy consistency finding, not a legal conclusion.

### 17. P2 — Network isolation depends on deployment discipline

`catalog_service.py:100` binds 0.0.0.0 while comments instruct users to share through Tailscale only. Binding all interfaces does not enforce that instruction. Bearer authentication helps, but the listener itself also accepts connections through other reachable interfaces.

Fix: bind to the intended private interface or explicitly enforce firewall/access configuration. Provide managed service startup and health checks; deletion currently depends on a manually started service and SSH tunnel.

### 18. P2 — Desktop state is spread across independent persistence systems

Theme application changes widgets.json, wallpaper settings and UserDefaults, with the backup only in UI memory. There is no durable transaction spanning these stores. Wallpaper deletion separately edits files, removed.json and catalog.json using numerous `try?` operations.

Consequence: interrupted or failed writes can leave a half-applied desktop or make an item return on relaunch. WidgetStore's visible saveError is a good existing pattern, but most other stores only log failures.

Fix: introduce a desktop-change coordinator with durable snapshots and commit state, explicit storage versions/migrations and a shared user-visible save/retry state. Do not rewrite the entire app to achieve this.

### 19. P2 — Display names are used as persistent identities

`AppServices.swift:300`, `DesktopWidgetController.swift` and `WallpaperController.swift:104` associate widgets, windows and wallpaper restoration with NSScreen.localizedName. WallpaperController collapses duplicate names into one dictionary entry.

Consequence: two monitors of the same model can share a name and collide; original wallpaper restoration and widget placement become ambiguous. Fix: persist a stable display identifier, with a defined fallback when displays change. A duplicate-monitor setup was not exercised physically.

### 20. P2 — AppServices is becoming the place everything depends on

`AppServices.swift` constructs settings, sensors, media, weather, GitHub, calendar, wallpaper, clipboard, notes, workspaces, audio and several controllers. Views accept this entire object; application workflows also mutate its UI state directly. `WidgetOptions` in `WidgetModels.swift:725` combines many unrelated widget configurations in one large optional/default-based structure.

Consequence: feature boundaries are hard to test independently, and inappropriate configurations remain representable. Fix: retain a composition root, but give pages narrow dependencies and move desktop installation/recovery into a dedicated coordinator. Split configuration into typed per-widget payloads incrementally.

### 21. P2 — Privacy defaults create a persistent clipboard archive immediately

`ClipboardStore.swift:104` enables history by default, line 113 disables clearing on quit, and line 296 writes readable JSON. Password-manager exclusions and private pasteboard markers are useful, but ordinary apps can still copy sensitive text and screenshots without those markers.

Fix: make history collection an explicit first-run choice, explain retention and pinned exceptions, offer age-based expiry and a pause control. Encryption at rest can be considered according to the intended threat model; do not imply the current archive is protected by the app.

### 22. P2 — Private platform integrations are a compatibility liability

`MediaHelper.m` loads private MediaRemote symbols through an Apple-signed Perl process. `AudioCapturePermission.swift` calls private TCC symbols and treats missing symbols as authorized/successful. These can change independently of this app.

Fix: isolate capabilities, expose unavailable/unknown states accurately, disable affected features gracefully and validate packaged builds across supported OS versions. Missing permission-check support should not be represented as proof of authorization. This review does not assert an App Store eligibility outcome.

## Verification, release and maintenance

### 23. P2 — Green tests do not validate the dangerous user journeys

The passing suite is valuable and includes persistence, cancellation and wallpaper failure cases. However, `WallpaperLibraryTests.swift` explicitly checks that failed remote deletion removes the local item; it does not test a successful retry afterwards. Core-only tests also cannot catch preview rollback on application quit or navigation regressions in the executable target.

Fix: add meaningful integration tests for delete failure/retry, wrong-ID asset deletion, same-size wrong-content offload, interrupted desktop changes and preview quit/relaunch. Keep server tests alongside the Python services.

### 24. P2 — CI creates evidence but does not enforce much UI/performance quality

`.github/workflows/ci.yml:64` accepts any nonzero screenshot count. The probe job emits numbers without budgets; its piped commands also lack explicit pipefail. A partial render can pass, and a probe process failure can be hidden by tee.

Fix: require the complete expected screenshot matrix, enforce selected layout and performance thresholds, and propagate process failures. Avoid treating screenshots existing as screenshots being correct.

### 25. P2 — Packaging is still for development

`scripts/build-app.sh:28` signs with a local development identity or ad hoc. There is no Developer ID notarization pipeline in this script, and CI tests the debug package rather than a distributed signed app. `Info.plist` includes a hard-coded personal-server address.

Fix: create a reproducible release pipeline with packaged-app smoke tests, signing/notarization and intentional server configuration. Pin the tested toolchain and validate the stated minimum OS, not just the newest development environment.

### 26. P3 — Competing implementations and stale documents make regressions easier

FloatingNav and CinemaNavigation coexist; ClassicGalleryPage and GalleryPage coexist; README still describes interactions not present in the active navigation. Many dated design reports describe different iterations. Some legacy code may still serve a harness, but its status is not obvious.

Fix: retain one active implementation per surface, document any intentional legacy harness, and keep a short authoritative architecture/product spec. Historical reports should not be the way maintainers discover current behavior.

## Suggested repair order

1. Protect layouts: preserve widgets on wallpaper change, persist preview rollback, provide durable undo.
2. Repair deletion and offloading: authoritative asset lookup, durable pending operations, verified digests and explicit error/retry states.
3. Fix catalog sync before the next run against uploaded rows.
4. Simplify Desktop navigation and distinguish sample data from installed widget settings.
5. Add integration coverage for these exact failure paths, then improve release validation and platform fallbacks.
6. Refactor service/configuration boundaries gradually while removing unused UI implementations.

Keep the existing strengths: the Core/UI split, serial clipboard writes, atomic file writes, corrupt-store preservation, cancellation coverage, bounded caches and energy policy. The priority is making the extensive feature set predictable and recoverable.
