# All Set — project review, 5 October 2026

Reviewed the current working tree, including the uncommitted Themes changes, against commit `d6c4512`. This is a project-wide engineering first pass, not certification that every UI state, sensor, or supported macOS version works. No application source or existing tests were edited.

The structure is sensible: `AllSetCore` contains models, stores, clients and layout logic; `AllSet` owns SwiftUI/AppKit presentation and controllers; separate C/Objective-C targets provide hardware and media integration. The central performance policy, bounded image caches, background sampling and isolated store tests are useful foundations. The main remaining risks found in this pass are asynchronous results arriving after state changes and display identity/selection.

## Validation

| Check | Result |
| --- | --- |
| `swift build -Xswiftc -warnings-as-errors` | Passed |
| `swift build -c release -Xswiftc -warnings-as-errors` | Passed |
| `swift test` | 313 tests; 309 passed, 4 failed, 35 failed assertions |
| Active `ArtShader.swift` | Metal source and render pipeline compiled successfully on this Mac |
| Python scripts | All 4 passed syntax compilation using `/usr/bin/python3` |
| Shell scripts | All 5 passed `bash -n` |
| Isolated wallpaper fixtures | Reproduced failed-delete retry loss and a download recreating a deleted file |
| Isolated ScreenshotStudio with an offline editor substitute | Reproduced an old reply replacing a newly loaded screenshot |

The repro programs used temporary directories, a fake token, a stub URLSession and an offline AI substitute. They did not contact the real wallpaper server or AI providers. Logs and harnesses are in `/tmp/allset-review-*`.

## Findings

1. **P1 — the current Themes changes fail the existing test gate.**

   Evidence: [ThemeCarouselLayout.swift](../../Sources/AllSetCore/Themes/ThemeCarouselLayout.swift), lines 17 and 97; [ThemeCardArt.swift](../../Sources/AllSetCore/Themes/ThemeCardArt.swift), line 92; [ThemeCarouselLayoutTests.swift](../../Tests/AllSetCoreTests/ThemeCarouselLayoutTests.swift).

   Four tests fail: `aWideWindowShowsThreeNeighboursASide` (1 assertion), `everyCardTucksBehindTheOneInFrontOfIt` (30), `depthFollowsDistanceFromTheCenter` (2), and `piecesSitInTheUpperPartWithoutCoveringEachOther` (2). The uncommitted changes increase tuck from 9 to 32 points, change depth scales, and enlarge the card-art hero. Tuck at a neighbour's scale is now 36–48 points against the test's 16-point label margin, and two pieces extend below the tested upper-art boundary. CI's test job will fail for this tree.

   These visual choices may be intentional. Resolve the intended layout contract and then update implementation, specification and meaningful assertions together; the old report's “313 passed” is not the result of this working tree.

2. **P2 — an old AI response can replace a newly opened screenshot.**

   Evidence: [ScreenshotStudio.swift](../../Sources/AllSet/Screenshot/ScreenshotStudio.swift), lines 59–62, 73, 95–111 and 220–223.

   `ask` captures the current image before awaiting. `load` replaces the image/history while that request is pending, and the New Screenshot/Open controls remain enabled. The old response subsequently calls `push` on the new history with no session identity check. The offline reproduction loaded a 20-pixel-wide image, started an edit, loaded a 40-pixel-wide image, and observed the displayed image return to width 20 when the old edit finished.

   Give each loaded screenshot a generation/session ID, cancel pending work on replacement, and reject stale completions, including errors and conversation messages. UI disabling alone would not cover the global screenshot shortcut.

3. **P2 — failed permanent wallpaper deletes cannot be retried.**

   Evidence: [WallpaperStore.swift](../../Sources/AllSetCore/Wallpaper/WallpaperStore.swift), lines 653–656; [WallpaperPages.swift](../../Sources/AllSet/Wallpaper/WallpaperPages.swift), lines 650–654.

   `deleteEverywhere` removes the catalog entry and local files before attempting the remote DELETE. If the tunnel/server/token is unavailable, it returns `localOnly`. A later call for the same ID immediately returns nil because `libraryVideo(id)` is gone. The tile also disappears, although its error message tells the person to try again.

   Reproduced with a stub: the first call returned `localOnly("HTTP 500")`; after changing the stub to success, a second call returned nil and the DELETE request count stayed at one. Persist a pending remote deletion containing the ID and paths, with an explicit retry surface that survives relaunch. Keep the existing local-delete behavior if desired.

4. **P2 — a download can recreate a wallpaper file after deletion.**

   Evidence: [WallpaperStore.swift](../../Sources/AllSetCore/Wallpaper/WallpaperStore.swift), lines 321–324, 431–443 and 595–624.

   `deleteLibraryVideo` deletes files and metadata without cancelling their downloads. A download already in flight can subsequently move its temporary file back into the deleted destination and mark the removed ID as locally copied. This is reachable from the detail preview, which starts fetching while its Delete button remains available.

   Reproduced: start a delayed fetch, delete the item, await completion; the catalog item stayed absent but its downloaded file existed again. Cancel downloads for all of the item's paths and reject deleted/stale download completions before installing files or changing membership.

5. **P2 — Add widgets ignores the display selected in the theme dialog.**

   Evidence: [AppServices+Themes.swift](../../Sources/AllSet/AppServices+Themes.swift), lines 55–60; [AppServices.swift](../../Sources/AllSet/AppServices.swift), lines 304–309.

   The add mode creates widgets with the chosen screen name, then passes them to `addWidget` without a slot. That method unconditionally replaces the screen name with `NSScreen.screens.first` and searches for room there. Selecting an external display therefore still adds the widgets to the primary display. Replace mode uses the selected target correctly.

   Pass the target display through insertion and calculate free slots on it. Validate both add and replace with two displays.

6. **P2 — identical monitor names collapse separate displays.**

   Evidence: [WallpaperController.swift](../../Sources/AllSet/Wallpaper/WallpaperController.swift), line 104; [AppServices.swift](../../Sources/AllSet/AppServices.swift), screen lookup; [AppSettings.swift](../../Sources/AllSetCore/Settings/AppSettings.swift), `screenFits`.

   The wallpaper controller builds a dictionary keyed by `localizedName`, explicitly keeping only the first screen for duplicate names. With two displays of the same model/name, only one gets a wallpaper window. Widget screen lookup and per-display scale settings share the same ambiguous key, so widgets and sizes cannot independently target both displays.

   Use a display identifier for runtime lookup and a persistent display identity for saved layouts/restoration. Keep names for labels and migrate old name-based records. This finding follows directly from the code; it was not tested with two identical physical monitors.

7. **P2 — turning wallpaper off during initial still generation can apply it afterward.**

   Evidence: [WallpaperController.swift](../../Sources/AllSet/Wallpaper/WallpaperController.swift), lines 230–248 and 266–274.

   `matchSystemWallpaper` sets `appliedSystemSource` before awaiting image generation/download. If wallpaper is disabled before the first match finishes, `restoreSystemWallpapers` returns early when there are no recorded originals, leaving that source token intact. The old task then passes its source-only guard and sets the system wallpaper despite the feature being off. Turning off system matching has the same issue.

   Invalidate/cancel pending matching before any early return, and check current enabled/matching state plus a request generation immediately before applying. This is a code-confirmed interleaving; no real desktop wallpaper was changed to reproduce it.

8. **P2 — one disappearing theme card cancels a preview still needed by another.**

   Evidence: [ThemePreviews.swift](../../Sources/AllSet/Studio/ThemePreviews.swift), lines 345–350 and 378–383; [ThemesPage.swift](../../Sources/AllSet/Studio/ThemesPage.swift), lines 372–375.

   Requests count how many views need each preview. `cancel` decrements that count but removes queued rendering even if the count remains positive. Featured, Trending and category rails can show the same theme/desktop preview. If one duplicate leaves while the preview is queued, the other can remain on a placeholder: its task key/generation has not changed, so it does not request again.

   Cancel queued preparation/rendering only when the final consumer releases it. Add a regression scenario with two consumers, one disappearing before drawing starts. This was verified by tracing the code, not by scrolling the live UI.

## Lower-priority contract checks

- A catalog item with `kind: image`, `still` populated and no `playback` downloads successfully, but `libraryURL` never resolves the file. The fixture reported `canPlay: true` while `libraryURL` was nil. The current importer writes image playback paths, so this is a compatibility edge rather than a demonstrated failure for current imports. Either support the accepted still-only shape throughout resolution/reload/offload, or reject it consistently.
- Cancelling one caller of a shared download keeps the download alive for the remaining caller, as intended, but the cancelled caller also waits until completion and returns success. The isolated fixture confirmed this. Decide whether callers require prompt cancellation and, if so, separate per-caller completion/cancellation from the shared transport task.

## Scope and next checks

The pass covered application startup/lifecycle, services, navigation, theme installation/previews, widgets and GPU art, persistence, wallpaper import/fetch/offload/delete, clipboard/shelf, screenshot editing/shortcuts, workspace/window control, audio routing, notch/knock/lid integration, build packaging, CI and existing tests. Review depth varied: controllers and stores received the most scrutiny; individual widget visual variants were not exhaustively rendered.

No live UI screenshots, latency/CPU/long-duration memory measurements, real destructive server actions, paid AI calls or permission-changing flows were run. The release packaging/signing/notarization path, older supported macOS versions, identical external monitors and sensor/capture behavior need separate integration coverage. Performance numbers in older reports should be treated as historical measurements, not results of this review.

Suggested order: make the current test gate consistent with the approved design; fix stale screenshot results and deletion lifecycle; then display targeting/identity, wallpaper matching cancellation and shared preview ownership. Add regression coverage for these state transitions without changing the user's current desktop to exercise them.
