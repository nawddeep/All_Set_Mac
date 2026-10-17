# Whole-project audit, fixes and scroll optimisation — 2026-10-08

Asked for: a blunt review of the whole project, every problem found, then debugging, fixing and optimising without compromising anything.

Read: app lifecycle, every store, the desktop-widget, wallpaper, notch, clipboard, media, mixer, hotkey and theme code, plus the newest theme work. Measured the running Dock app and the probe build. No commit or push.

## Verified state

- Debug build: 0 warnings. `swift test`: **442 tests in 103 suites pass** (441 before; one added).
- Dock app `build/AllSet.app` rebuilt with `./scripts/build-app.sh`, signed "All Set Development", relaunched. No errors or faults logged in its first four minutes; no crash reports on this Mac.
- Idle, before the changes: 3.2% CPU, about 25 idle wakeups a second, 85 MB. A sample showed the main thread idle; the CPU is the live video wallpaper being decoded.

## Bugs fixed

| # | Problem | Fix |
|---|---|---|
| 1 | **Undo, a preview's Go Back and Restore Previous Desktop could leave the system wallpaper stuck on a theme's still.** The snapshot put back the whole wallpaper config, including the list of original system wallpapers, which is filled in *after* the snapshot is taken. With that list emptied, turning the live wallpaper off restored nothing. The library server address was reverted the same way. | `DesktopSnapshot.restore` keeps the current `originalWallpapers` and `libraryServerURL`. New test `restoringKeepsWhatWasLearnedSinceAboutTheSystemWallpaper` failed before the fix and passes after. |
| 2 | The previous system-wallpaper still was deleted before its replacement existed. If the new one couldn't be made, the system wallpaper pointed at a deleted file. | `WallpaperController` deletes old stills only after the new one is set. |
| 3 | A widget removed mid-drag or mid-resize (theme applied, Undo, widgets hidden) left the drag open for good, which stopped the grid tidying itself for the rest of the session. | `DesktopWidgetController.closeWindow` clears the drag and resize state for that widget. |
| 4 | Copying an item from clipboard history didn't move it to the top, though the code says it does: it was re-added with its old date. | `ClipboardMonitor.copy` dates it now. |
| 5 | Importing wallpaper videos copied files on the main thread: a large file from another volume froze the window. | `WallpaperStore.importVideos` is async and copies off the main thread. |
| 6 | A picture dragged from a browser onto the shelf used the page's suggested name unsanitised. A `/` in it made the save fail silently. | Path separators are replaced. |
| 7 | `fitWidgetsToScreen` would trap on a layout file that repeats a widget id. | Uses `uniquingKeysWith`. |

Fixes 2–7 were made from reading the code; they have no automated test (2–6 are in the app target, which has no test target) and were not exercised by hand.

## Optimisations, measured

| Change | Before | After | How measured |
|---|---|---|---|
| **Window not movable while a scroll is in progress** (`ScrollingWindowRelief`, `MainWindow.swift`). The content runs under the title bar, so AppKit rebuilds the window's drag region every frame and SwiftUI walks every card to answer: 19% of main-thread samples on Themes, 26% on Gallery. | Themes 46.0–46.5% CPU, p95 20.8–21.0 ms. Gallery 53.3–58.8%. Wallpaper 67.1–67.9%. | Themes 39.4–39.9%, p95 18.7–18.9 ms. Gallery 45.6–50.1%. Wallpaper 64.7–65.5%. | `-probe scroll`, interleaved before/after/before/after, `NORELIEF=1` for before. |
| Wallpaper catalog checks moved off the main thread at launch. | 83–95 ms main-thread hold on the real 1,161-item catalog. | Off the main thread. | Standalone timing of the same code on the real catalog. |
| Theme-widget catalog deduplicated by comparison instead of JSON-encoding each widget. | 94 main-thread samples on first Gallery visit (release); 128 ms in a debug test. | 26 ms in the same debug test. Same 1,142 widgets, identical ids. | Sample of the probe; temporary test comparing count and id hash. |
| Wallpaper card caption drawn as one text instead of three. | 64.7–65.5% CPU. | 62.4–63.8%. | `-probe scroll`, `ONLY=wallpaper`, two runs. Caption checked in a render. |
| Clipboard timer no longer runs while history is off. | Two or more wakeups a second for nothing. | None while off. | By reading; not measured. |

The window is movable again the moment a scroll ends, and within 0.4 s of the last movement if a scroll never reports its end. The probe prints this after every pass (`window movable: after the scroll true, mid-scroll false, 1 s after an unfinished scroll true`). **Not checked by hand:** dragging the window by its top edge right after a trackpad scroll in the real app.

The scroll probe now posts `didLiveScrollNotification` on every step, as a trackpad does.

## Still open

**Performance**
- Scrolling is still expensive: Wallpaper 63%, Gallery 46–50%, Themes 40% of a core in the probe. What's left is SwiftUI layout and Core Animation commits, not app code (under 1% of main-thread samples).
- About 10% of main-thread samples on every page are SwiftUI re-hit-testing hover on each scrolled frame.
- The main thread blocks on the window server while new text layers arrive: 17% of samples on Wallpaper, 10% on Gallery.
- Each wallpaper tile carries its own confirmation dialog and alert. Moving them to the page would lighten 1,000 tiles; it needs the dialog's anchoring re-thought.
- Desktop widgets poll the pointer 20 times a second whenever any widget is uncovered. It didn't show in a sample, but it is most of the idle wakeups. A global mouse-moved monitor would remove it; a 15-second test of one saw no pointer movement, so that is unproven.

**Product and release**
- The app target (UI, controllers) has no tests. Everything risky that isn't in `AllSetCore` is verified by eye or not at all.
- Self-signed, not notarised, private APIs (MediaRemote through perl, IOKit sensors, symbolic hotkeys), GPL Lid Plane, 1,161 unlicensed Workshop wallpapers: this can't be distributed as it stands.
- Clipboard history is plain JSON on disk.
- `allset://theme/<id>` and `allset://focus/…` change the desktop with no confirmation.
- Themes carousel: captions and the Featured pill sit on top of widget content; heart buttons cover card content in the shelves; the filter bar truncates ("Top P…").

**Repository**
- `.git` holds 2.09 GiB of garbage: six `tmp_pack_*` files from interrupted transfers. `git gc --prune=now` clears them.
- Build products are in history (`.build/out`, a 58 MB debug binary, dSYMs, a 29 MB screen recording): the pack is 674 MiB.
- Four remotes, one dead; nine local branches.
- `HANDOFF.md` contradicted itself on test counts; corrected in this session.
