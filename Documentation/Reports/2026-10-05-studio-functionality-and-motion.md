# Widgets and Wallpaper: scrolling, complete libraries and motion

Date: 2026-10-05. Follow-up to the cinematic implementation, prompted by the user's report that the attractive first viewport hid the existing content and lacked scrolling/motion.

## Result

The cinematic Widgets page now contains the entire original library in its main native vertical scroll: **91 catalog entries and 634 themed widgets**. Purpose filters and search include both. Clicking a catalog preview opens the original `GalleryCard` controls, preserving the existing size/material choices; its Add and drag paths still use the existing services. The themed cards preserve their original instances and identify their theme.

Wallpaper retains the approved full-window scenery, lower caption/actions and five-card filmstrip as its first viewport. Scrolling continues into a uniform lazy grid for every entry in the chosen source. The current running library reports **119 Aerial Videos choices** (five bundled scenic choices plus the aerial catalog), **943 Art combinations**, and **986 My Videos entries**. These counts reflect the current stores, not new imports or copies. Import, drop and the existing advanced browser remain available.

`CinemaNavigation` is now the same two-row navigation on every main-window page, including Themes. Primary and secondary selection pills use matched geometry; page content crossfades. Widget spotlight arrows, horizontal trackpad gestures and mouse drags use directional spring transitions. Vertical gestures over the stage continue to the page scroll. Motion uses the existing Reduce Motion policy. The navy widget scenery, outline glow and reflection remain.

## Changes at the core of the UI

- One scroll document contains spotlight, recommendations and complete catalog. A pinned toolbar remains outside it. Returning to All restores the spotlight; filtered/search results begin at their catalog heading.
- Fixed-height lazy rows let AppKit measure large documents without constructing every widget. The wallpaper grid uses identical widths, 16:9 images and consistent caption space, including incomplete final rows. Filmstrip buttons and captions have explicit equal widths, so long video names cannot distort spacing.
- `LibraryPreviewCache` is bounded to 32 MB/80 images, keys the complete widget instance and fit, and stores still native previews. Only hovered library cards mount live widgets. Cache clearing follows main-window close.
- Thumbnail generation and publishing wait for scrolling to settle. Native clip-view bounds notifications cover mouse wheels and scrollbar drags as well as trackpad live-scroll notifications. Waiting tasks are cancellable; there is no permanent polling timer.
- My Videos thumbnails use the existing personal-server `fetchThumbnail` path when the local image is missing. Browsing does not fetch full videos. Unavailable remote media still depend on server connectivity.
- The Art library exposes every style/palette combination while retaining the original style-only IDs for midnight pieces, preserving earlier Art selections/favorites.
- A stronger top fade keeps navigation readable over bright selected wallpapers.

## Review and verification passes

These are distinct checks and improvements, not ten copies of the same test or a pixel-accuracy claim.

| Pass | Check | Result / improvement |
|---|---|---|
| 1 | Original catalog and themed instances | Complete arrays restored; tests compare IDs and full instances with original catalogs. |
| 2 | Main page scrolling | Real scroll document reaches the original catalog and deeper themed content; toolbar stays pinned. |
| 3 | Purpose/category filtering | Core filters cover original and themed widgets. Live Clocks shows six catalog entries plus 62 themed entries. |
| 4 | Original clock controls | Live Digital Clock editor changes Medium → Large and Photo → Frosted with visibly different native previews. |
| 5 | Filter reset | Live Clocks → All restores the spotlight at scrollbar value 0. Theme captions now show their set names. |
| 6 | Spotlight movement | Next selects Analog Clock; Previous returns to Digital Clock. Directional transitions and shared Themes gesture catcher are wired; vertical movement reaches the page. |
| 7 | Consistent navigation | Live Island, Themes, Widgets, Tools and System expose the same navigation component. Section/page selection and remembered Desktop route work. |
| 8 | Wallpaper reference comparison | Full alpine hero, top navigation/source bar, lower caption/actions and five-card filmstrip checked in native renders and the visible app. |
| 9 | Wallpaper symmetry | Exact grid width/aspect tests across 900–2560 pt; live aerial and video grids show aligned five-column rows. |
| 10 | Complete Wallpaper sources | Live source switches report 119 aerial choices, 943 Art variants and 986 video/library entries; scrolling reaches later rows. |
| 11 | Search recovery | Native keyboard input produces No wallpapers found; Clear restores all 986 video/library results. |
| 12 | Scroll cost | Cold and warm optimized probes run after the lazy rows, fixed filmstrip geometry and scroll-quiet preview scheduling changes. Metrics below. |
| 13 | Compatibility / release | Art ID uniqueness and legacy midnight IDs checked, all 334 tests in 86 suites pass, production build and signature verification pass. |

Native renders at 900×600 and 1586×992 are in `build/review/studio-functionality/final-renders/`; these precede the last small caption/reset/thumbnail/header changes. Earlier live captures are in `build/review/studio-functionality/live/`. Visible-window checks used CUA after the caption/reset delivery build; the subsequent thumbnail/header build was launched before the user requested the October 6 Wallpaper restoration. That restoration supersedes this Wallpaper presentation. Live time, weather, system readings and media are real data and naturally differ from the static references. The scenery is the original generated asset already selected for the implementation; it is not an extracted screenshot background. No new numeric pixel-match score is claimed.

## Performance evidence

Optimized DEBUG scroll probes at 1280×800, from `verified-gallery-scroll.log` and `verified-wallpaper-scroll.log`:

| Page / run | App CPU | Frame p95 | Worst frame gap | Gaps >33 ms |
|---|---:|---:|---:|---:|
| Widgets, first sight | 40.8% | 19.9 ms | 35.5 ms | 1 |
| Widgets, warm | 27.1% | 18.1 ms | 23.4 ms | 0 |
| Wallpaper Aerials, first sight | 31.3% | 18.1 ms | 25.7 ms | 0 |
| Wallpaper Aerials, warm | 29.9% | 18.0 ms | 48.3 ms | 1 |

The earlier wallpaper runs contained multi-second stalls; the final measured runs do not. This does **not** establish that every cold scroll is hitch-free, measure isolated GPU/WindowServer cost, or benchmark the server-backed video library. The catalog now has substantially more content, so this is not a controlled before/after speedup percentage. The last delivery changes affect caption text, filter reset, Art identity, header contrast and missing remote thumbnails; these measurements were taken before those delivery changes.

## Build and evidence boundaries

- `delivery-tests.log`: **334 tests in 86 suites pass**, including restored catalog/skin equality, filtering/search, uniform wallpaper geometry and unique compatible Art IDs.
- `thumbnail-delivery-release.log`: last cinematic production bundle build. The prior `signing.txt` and `binary-identity.txt` verify the earlier frozen build; later delivery signature/identity files were not written before the task was interrupted for the October 6 restoration.
- Intermediate failed builds and failed native UI harness runs remain in the artifact directory. They are not counted as passing evidence. The final native scripted harness failed at a window lookup; offscreen/Space state and stale UI targets also disrupted earlier attempts. Visible-window CUA checks supersede those incomplete interaction runs. The unexecuted `animation-check.swift` is a draft helper, not verification evidence.
- Add/save/remove persistence was verified in the preceding implementation session. This follow-up did not press Add, Apply Theme, Set Wallpaper or deletion controls and does not claim a new persistence test.
- The final bundle replaces the same `build/AllSet.app` used by the Dock. No commit or push. Existing desktop widget and wallpaper data were preserved.

## Main files

`Sources/AllSet/Studio/CinematicWidgets.swift`, `CinematicCatalog.swift`, `LibraryWidgetPreview.swift`, `ThemeWidgetGallery.swift`, `WidgetStudio.swift`; `Wallpaper/CinematicWallpaper.swift`; `Design/CinemaDesign.swift`; `MainWindow.swift`; `AppServices.swift`; `AllSetCore/Widgets/StudioDiscovery.swift`; `Tests/AllSetCoreTests/StudioDiscoveryTests.swift`.
