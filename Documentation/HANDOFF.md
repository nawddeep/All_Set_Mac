# All Set: Handoff

**Read this first at the start of every session, instead of reviewing the codebase**, then `Documentation/PRODUCTION_READINESS_REPORT.md` for the latest large change and `Documentation/OWNER_ACTIONS.md` for what waits on the owner. For what the app contains, see `CONTENT.md`; for how to build, test and release, `CONTRIBUTING.md`. Only open the source files the task at hand needs.

_Last updated: 2026-10-18 (production-readiness run on branch `fix/production-readiness`, 44 local commits from `5e7f5ee`, not pushed)._

## Current state (2026-10-18)
- **Supplied themes integrated (Funky Themes, 70 in seven batches; the first 20 by batches 1-2, the rest from `themes_update/batch`):** each design's own collage is its wallpaper, with the painted clock, calendar, music and notes cleared from their cards and the menu bar and Dock removed (`scripts/prepare-funky-themes.py`, needs Pillow/NumPy/OpenCV; positions and looks in `design/provided-funky-themes/layout*.json`, generated into `FunkyLayouts.swift` and `FunkyThemesMore.swift`). Live widgets sit on those cards at the traced spots, sized with the widget's own scale; `FunkyThemes.fitted` keeps them on their cards on any screen. Details and limits: `Reports/2026-10-18-funky-themes-integration.md`.
- **The production-readiness run** fixed or addressed the 37 findings of the October review; the table of what changed, how it was checked and what's open is `Documentation/PRODUCTION_READINESS_REPORT.md`. Decisions with their reversals: `Documentation/DECISIONS.md`. Checklist and measurements: `Documentation/PRODUCTION_READINESS_PROGRESS.md`.
- **Product shape now:** four pillars (Island, Widgets, Themes, Wallpaper) plus eight Extras, each with a switch (`ExtrasSettings`; off for new installs, all on for installs from before). Navigation: Island, Desktop, Extras, Settings (⌘1–⌘4). First-run onboarding for new installs only.
- **Gone:** Lid Plane (GPL), Wallhaven, knock shell commands, the `sudo purge` button, Wallpaper Engine tooling (moved to `../AllSet-personal`), real people and club trade dress in themes (old theme/palette ids still load via `LegacyIdentifiers`).
- **New structure:** `AppFeatures.swift` (feature coordinators; `AppServices` forwards the old short names), widget kinds defined one file each in `Sources/AllSetCore/Widgets/Kinds/`, `Capabilities` (every private macOS interface, with kill switches), `NetworkUse` (every host; a test enforces it), `pgsql.py` on the server (values never in SQL text). No source file over 600 lines.
- **Distribution:** hardened runtime + `Resources/AllSet.entitlements` on every build (dev/ad hoc also relax library validation so Sparkle loads); `scripts/notarize.sh`; Sparkle 2.9.6 embedded but off until the owner's key exists.
- **Tests:** 469 Swift (5 clean runs in a row), server 117 (69 skip without Postgres), `-smokeTest` 44/44 on throwaway data, 0 warnings. CI adds smoke, minimum-os (arm64-apple-macos14.2) and optimised-build probes with budgets.
- **Open, measured:** scroll CPU (Themes ~41–49%, Gallery 30–60%, Wallpaper library 59–100%) is far above the 20% target, and switching to Themes holds the main thread 75–140 ms; profiling puts it in SwiftUI's graph for the whole page. Thread Sanitizer won't load on this Mac. The 228-file restructure is blocked (stale plan). App-side widget registration is still switch-based. All in OWNER_ACTIONS.md.
- **Never verified by a person yet:** the hardened app's Calendar, mixer and hotkeys; uninstall; a deep link from a browser; the live seconds clock layer; anything on macOS 14/15 or a second monitor. `Documentation/RELEASE_CHECKLIST.md` covers them.
- Session history before this run, and notes about this Mac and Claude Code, are in `../AllSet-personal/HANDOFF-history.md`.

## Standing instructions from the user
1. **After every change, rebuild and replace the Dock app:**
   ```sh
   ./scripts/build-app.sh
   osascript -e 'tell application id "com.pratik.allset" to quit'
   open build/AllSet.app
   ```
2. **Optimise at the core level** with every change: CPU, GPU and WindowServer cost. Measure it; don't assume.
3. **Copyright:** themes are *original*, inspired by an era, genre or mood. No logos, album art, promo photos or trademarks. No real person, club or nation is named anywhere, hidden search tags and comments included (`RealPeopleDenylistTests` scans data and source). The user's player photos stay on their Mac, never in the repo.
4. **Save tokens:** read this file and the latest report instead of re-reviewing the project. End every session by updating this file and writing a report.
5. Commit or push only when asked (the user has approved commits at each verified checkpoint this session; never push without being asked). The current repository is remote `final` → github.com/nawddeep/All_Set_Mac, branch `final-main`; `cloud` (github.com/pratik-aep/all-set-mac-app) is the older one.

## Current Widgets and Wallpaper design
- Widgets: `Studio/CinematicWidgets.swift`; Dark default; all 91 catalog entries and themed widgets remain available. Studio Originals contributes 260 individually usable presets, Desktop Edit contributes 227, and Monochrome Edit contributes 21 in separate groups. Widgets and Wallpaper share the cached Midnight Aurora Themes atmosphere via `StudioThemeStyle.swift`. Every page uses the same `CinemaNavigation`.
- Wallpaper: `Wallpaper/WallpaperPages.swift` → `ClassicWallpaperPage`: a Built in section (36 generative live wallpapers, `BuiltInWallpaper`) first, then `VideosSection`. No Aerial/Art/My Videos tabs, source bar, Aerial service, unused cinematic replacement, or source-tab state. Search and horizontally scrollable category filters live in the library. Full-bleed hero preserves current desktop media; imported library, import/drop, sorting/Owned filters and details remain. Shared art models remain for Themes/widgets; old Art deep links now open the video library.
- Aerial active data retired into `build/backups/retired-wallpaper-sources-2026-10-06/`: 71 cached manifest/preview files, one Aerial download, one retired preference. Video/server library records remain. `WallpaperCategory` preserves existing catalog JSON categories independently of the deleted Aerial model.
- Spotlight preview, shadow and floor light share the fitted widget footprint and animate size changes. `StudioSegmentedControl` supplies independent sliding highlights for size/style, including Customize, with Reduce Motion support.
- The three Monochrome Edit themes have explicit checks for offline decoding, editable widget presets, persistence and compact-screen spacing. Their desktops, cards and widget sheets were rendered and inspected in `build/review/dataset-two-2026-10-08/`; earlier evidence remains in `build/review/studio-originals-six/` and `build/review/desktop-edit-2026-10-08/verified/`.
- Theme-widget lookup is indexed by set id: 12,500 warmed lookups measured 5.19 ms versus 10,929.52 ms for repeated full-catalog scans. Theme artwork is still; preview caches remain bounded and scroll-aware. Whole-Mac GPU/WindowServer readings are activity-dependent, so no isolated improvement claim is made.
- Themes now total 110. **Monochrome Edit** is separate from **Studio Originals** and **Desktop Edit**. Dataset 2 consists of 19 low-resolution screenshots of laptop setups/search results, used as visual references rather than shipped as wallpaper; three distinct directions were implemented with existing high-resolution offline art. Five supplied cosmic wallpapers are applied to Studio Originals; the remaining concepts there still use native-art foundations. Exact Dock bundle: `build/AllSet.app`, rebuilt and development-signed. No commit/push.
- Approved design references: `design/widgets-concepts/SELECTED.md`, `design/wallpaper-concepts/SELECTED.md`; previous unified visual style report remains `Reports/2026-10-06-unified-studio-theme-style.md`.

## Build, test, verify
| What | Command |
|---|---|
| Debug build (expect 0 warnings) | `swift build 2>&1 \| grep -c warning:` |
| Tests (469 in 113 suites on 2026-10-18) | `swift test` |
| Optimised build with DEBUG tools | `swift build -c release -Xswiftc -DDEBUG --build-path .build-probe` |
| Everything, on GitHub | CI (`.github/workflows/ci.yml`, `macos-26`) on every push: `build-and-test` (fails on any warning), `screenshots` (`-renderPages`, published to the `ci-screenshots` branch) and `probe` (`-probe scroll`, `pages`, `galleryparts`, in the run summary). Cloud sessions without a Swift toolchain verify through CI only |

Run DEBUG tools as `.build-probe/release/AllSet <flag> -skip window,wallpaper,widgets,notch`.

**`-probe <name>`** prints numbers:

CI's `probe` job runs `scroll`, `pages` and `galleryparts` on every push (debug build) and puts the numbers in the run summary.

| Name | Measures |
|---|---|
| `pageswitch` | Main-thread hold per page click in the real window (`ONLY=gallery REPEAT=10`); `scroll` also takes `ONLY=` |
| `islandmotion` | Frames lost per open, tab switch and close; `COLD=1` skips the warm-up |
| `systembuild` | System-tab build time |
| `search` | Live search results per source |
| `mystic` | CPU of the newest widgets |
| `fans` | Football and music widgets |
| `widgets` | Widget CPU |
| `gallery` | Gallery page CPU |
| `apply` | Theme apply cost |
| `reveal` | Theme reveal cost |
| `windowserver` | WindowServer CPU |
| `pages` | Page CPU (the default when no name is given) |
| `scroll` | Themes, Gallery, Art and Wallpaper scrolled a step a frame, twice each (first sight, then warm): CPU, frame gaps, worst stall. Holds off App Nap and posts live-scroll notifications like a trackpad. On a GPU-less CI VM frame gaps sit near 80 ms on every page (the window server, not the app): compare CPU and the worst stall |
| `galleryparts` | Build time of one Gallery card and of each of its parts |
| `windowclose` | Monitor viewers, CPU and footprint around opening and closing the main window (Themes page) |
| `covered` | A widget visible vs. covered; `ENTRY=`/`SIZE=` pick it |
| `desktopwidgets` | Each of the user's desktop widgets alone; `ONLY_KIND=`, `SECONDS=` |
| `neon` | Neon flicker on vs. off over 60 s |
| `wallpaperlibrary` | 1,008 library entries in the real main window: scroll, switch, close, 5 cycles, plus pausing rules. **Quit the Dock app first**; restores your wallpaper |

**`-render<X> <folder>`** saves PNGs to look at:

| Flag | Shows |
|---|---|
| `-renderIsland` | Island states and mid-spring frames |
| `-renderPhotos` | Photo search (the picture picker's Photos view) after real searches |
| `-renderEntries dir -entryCategories a,b -entryIDs x,y` | Gallery widgets, live and still |
| `-renderThemeSets` | Theme set previews and pages |
| `-renderScaling` | Widget scaling |
| `-renderGPUArt` | GPU art |
| `-renderDesign` | Real-window capture of design themes |
| `-renderWallpaperLibrary` | My Videos with the imported library |
| `-renderPages` | Every main-window page at 900×600, 1280×800, 1728×1080 (`-pages a,b`, `-pageSizes WxH,…`). CI runs it on every push and force-pushes the latest set as JPEGs to the `ci-screenshots` branch (`git fetch origin ci-screenshots`) |

**Design system (2026-09-30):** the main window is always dark. Tokens and shared components are in `Sources/AllSet/Design/` (`DS.Space`, `DS.Radius`, `DS.Ink`, `DS.Surface`, `.dsText(role)`, `.dsFormStyle()`, `PageScaffold`, `PageHeader`, `HeroSection`, `MediaCard`, `MediaRail`, `GlassPanel`, `.pill`/`.pillProminent`/`.floating`, `FilterPill`, `SearchField`, `EmptyState`, `FlowLayout`, `FormPage(eyebrow:title:subtitle:lead:content:)`). New or reworked pages use these instead of literals. **Backdrop (2026-10-01):** the window draws one `WindowBackdrop` (`Design/WindowBackdrop.swift`): a deep navy canvas and four blue glows drifting on Core Animation layers, frozen by `PerformancePolicy.pausesDecorativeMotion` and while the window is occluded. Pages don't paint a background over it (`AppBackground` is only an accent glow); keep page and list backgrounds transparent. Pages that lead with media use `BleedScrollPage` with `HeroSection(bleed:)`: the hero runs under the navigation and fades into the backdrop, and sets `UIState.mediaUnderNavigation` so the navigation drops its fade. Navigation is `CinemaNavigation` (`Design/CinemaDesign.swift`, ⌘1–⌘5 for the sections; `FloatingNav` was removed 2026-10-06) with `NavSection`/`NavItem` in `Design/AppNavigation.swift`: `NavSection.of(page)` maps every `AppPage` to one of five places, and `NavItem.items(in:)` lists each place's pages; a new page needs a case in both. The window has no visible title bar (`MainWindowController.dress`), so every page names itself with a `PageHeader` or `FormPage` title.


**Profiling:** `xctrace record --template 'Time Profiler' --attach <pid> --time-limit 60s --output x.trace`, then `xctrace export --input x.trace --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' > x.xml`, then aggregate with `/usr/bin/python3` (the Homebrew python lacks expat) with a short script that sums main-thread samples per frame. The "CPU Profiler" template records nothing on this Mac; use "Time Profiler". `xctrace --launch` can leave a copy stopped at dyld (state `T`): check `ps -o stat` and kill it. `leaks <pid>`, `heap <pid>` and `footprint <pid>` work without sudo; `powermetrics` needs sudo (not available).

**Measure honestly:** app CPU doesn't include Core Animation, which runs in WindowServer. The user is active while you measure, so compare interleaved A/B runs.

## Architecture map
SwiftPM, macOS 14.2+, Swift 6. The targets are:
- `AllSet`: the app, AppKit plus SwiftUI.
- `AllSetCore`: models and services, unit-tested.
- `CPrivateAPIs`: IOKit sensors.
- `MediaHelper`: a dylib that `/usr/bin/perl` loads for Now Playing.

**Core pieces**
- `AppServices.swift` owns every store and service. `observe()` is a `withObservationTracking` loop; call it as `AllSet.observe` inside an NSView.
- `AppDelegate.swift` handles launch and all the DEBUG flags.
- `MainWindow.swift` defines `AppPage`, the list of every page.

**Dynamic Island** (`Sources/AllSet/Notch/`)
- `IslandView.swift`: an NSView that draws the island's body, shadow and mask as Core Animation spring paths, so the shape animates in WindowServer. It also has `warmUp`, which builds every tab off screen 2 seconds after launch.
- `NotchRootView`: the content only.
- `ExpandedPanel`: a fixed frame the size of the largest tab; only the current tab is mounted, and tabs slide with `.tab(direction:)`.
- `NotchAnimation`: springs, plus `RevealEffect`, `RetractEffect` and `SlideEffect`, which use opacity, scale and offset only (never blur).
- `NotchController`: the panel window, pointer handling, live activities and haptics.
- Tabs: `HomeTab`, `TrayTab`, the Mixer tab, the Notes tab and `SystemTab`. SystemTab's cards get exact frames from a GeometryReader.

**Widgets**
- Models live in `AllSetCore/Widgets/`:
  - `WidgetModels.swift`: `WidgetKind` (54 kinds), `WidgetCategory` (9), `WidgetOptions` (decoded per key, tolerant) and per-kind defaults.
  - `WidgetCatalog.swift`: 91 gallery entries.
  - `FanModels.swift` and `MysticModels.swift`: the zodiac, tarot, aura, charm and magic-ball data.
  - Themes: `WidgetTheme*.swift` (58 looks: 14 moodboards, 22 fandom, 13 core, 8 Colour & Light and Midnight Aurora) and `DesignTheme.swift` (15 skins). `ThemeLibrary` holds the 58 complete desktops the Themes page shows.
- **2026-10-03 grid change:** the grid pitch is a *quarter* of a small cell (92 pt): small 2x2, medium 4x2, large 4x4, XL 8x4, Extra Small (scale 0.45) 1x1. `WidgetGrid.spread` fills a wide screen after a theme installs; dropping a widget on one of the same size swaps them. Widget size is per display (`settings.screenFits`, `services.widgetScale(on:)`); a resolution or monitor change runs `refitWidgetsToScreens` (`WidgetLayout.refit`).
- **Placement is a snap grid** (`AllSetCore/Widgets/WidgetGrid.swift`, tested in `WidgetGridTests`): slots the size of a small widget, `spacing` apart, centered in each screen's visible area, margin kept in *screen* points (`WidgetLayout.margin / widgetScale`, as `fitted` does, or themes lose a column). `place(near:)` for drops, `firstFree` for adds (columns from the left), `arranged` for Clean Up (group shifted onto the lattice first, so every theme keeps its exact shape; larger widgets choose first). `DesktopWidgetController.tidyIfShapeChanged` runs Clean Up whenever sizes, membership, screens or the widget scale change, so a new Mac or display reflows. Compare screens by `displayID`, never `NSScreen ==` (new objects each call). `WidgetGridOverlay` (Core Animation, shown only during drags) draws free slots and the target; gallery cards `.onDrag` set `ui.widgetDrop`, which lifts the widgets, dims the screen and makes the overlay a drop target. Right-click menu: `WidgetMenuItems` from the `widgetMenu` environment; widgets with their own `.contextMenu` append it after a divider.
- **Corner resizing** (every widget, themed or not): `WidgetInstance.scale` (0.6–3, decoded as 1 when missing) multiplies the size's designed dimensions; `footprint` is what every placement path uses (grid spans are whole cells reached, `WidgetGrid.span(of: CGSize)`). Dragging the bottom-right `ResizeHandle` (shown on corner hover via a 20 Hz timer reading `NSEvent.mouseLocation` in `DesktopWidgetController.pointerMoved` -> `WidgetWindow.pointerMoved` (macOS sends no mouse-moved events to an app that isn't in front: tracking areas and global/local monitors can't work for desktop widgets), always while arranging) goes through `DesktopWidgetController.handleResize`: live `WidgetWindowState.liveSize/liveScale`, window grown from its top-left; `WidgetResize.resolve` (AllSetCore, tested in `WidgetResizeTests`) picks the kind's layout closest in shape and size, sticky near changeovers, snapping to scale 1 within 3%, kept within the grid and screen. On release `resizeWidget(_:to: Result)` saves and `cleanUpWidgets(keeping:)` keeps it in place while the others make room. Right-click offers "Reset to <Size> Size". `-widgetsFile /tmp/x.json -probe resize -resizeOut dir` drives a real window's corner through five sizes and saves PNGs (not yet run).
- **Free-form resize, Extra Small, display choice** (2026-10-03): `WidgetInstance.stretch` (height relative to width, 0.1–6) lets width and height scale independently (`WidgetResize.Result.stretch`; scale range now 0.4–3); Edit Widget has Width/Height sliders (the hover handle was never confirmed on screen, the sliders don't depend on it). Extra Small = small layout at `WidgetResize.extraSmallScale` (0.52), in the right-click Size menu for kinds that have Small. `WidgetLayout.margin` is 8 and `AppSettings.widgetScaleRange` 0.4–2. Theme install/preview asks which display when several are connected (`AppServices.chooseThemeScreen`, NSAlert) and replaces only that screen's widgets, keeping the widget size if others remain. Not verified on a real second monitor. NOTE: the Dock app is `build/AllSet.app`, only `scripts/build-app.sh` updates it.
- **Theme widgets in the gallery:** `ThemeWidgetCatalog` (core) currently flattens 1,142 themed widgets, repeats removed by comparing them without their ids; setup fonts and corners are copied onto each instance. `CinematicCatalog` includes them in the main scroll and in purpose/search results; `ui.galleryFromThemes` selects only themed entries. `ThemeWidgetGallery.swift` retains the original card/Add/drag behavior.
- **Text options on every widget** (`WidgetOptions.font`, `cornerRadius`, `textCase`, `renamedText`, `footnote`, `footnoteStyle`). Built-in labels go through `WidgetWord(...)` (`Widgets/Design/WidgetWord.swift`), which shows the rename and reports the original via `WidgetWordsKey`; the inspector's preview collects those, so the editor lists exactly the words on screen. New fixed labels in widgets should use `WidgetWord`, not `Text`. The caption draws in the window's bottom margin, so it never needs a slot.
- Views live in `AllSet/Widgets/Kinds/*.swift`. `WidgetHostView.swift` has the kind → view switch and `WidgetSurface`. `DesktopWidgetController` manages the desktop windows, scaled by `settings.widgetScale` (0.7–1.6).
- Motion goes through `Components/LiveLayers.swift`. `LiveLayerView` subclasses run Core Animation loops at capped frame rates and stop when covered or when Reduce Motion is on. Each one also draws a still SwiftUI version for snapshots (`widgetSnapshot` environment value). Building blocks:
  - `LiveArtwork`: float, shine and glow, cached in `ArtworkCache`.
  - `PulsingGlow`, `Sparkles`, `BlinkingLight`, `EqualizerBars`.
  - `TwinkleLayer`, `AuraLayer`, `FlameLayer` and `SpiralLayer`, in `MysticWidgets.swift`.

**To add a widget kind:**
1. `WidgetModels`: the `WidgetKind` case; then its definition file `Sources/AllSetCore/Widgets/Kinds/<Kind>Kind.swift` (title, symbol, summary, keywords, sizes, default size, freeform/own-background flags, starting look) and a line in `WidgetKindDefinition.all`.
2. An entry in `WidgetCatalog`.
3. A view, plus a case in the `WidgetHostView` switch.
4. `WidgetOptionsEditor`: its section and `showsStylePicker`.
5. The `looks` list in `WidgetStudio`.

**Search and photos**
- `AllSetCore/Aesthetics/PhotoSearch.swift` searches Openverse only, asking for and keeping CC0, PDM, CC BY and CC BY-SA (`allowedLicenses`).
- `Search/WallpaperQuery.swift`: filler words, place nicknames, `-word` exclusions (filtered on titles), spelling fixes.
- `Search/AestheticSearch.swift`: aesthetic vocabulary and spelling.
- Openverse allows at most `page_size` 20 for anonymous requests; more returns a 401.
- The UI is `Studio/LibraryPages.swift` (`WebPhotosPage`, `SearchFilters`, `RecentSearches`), reached only through `LibraryPicker`, the picture picker of Photo, Polaroid and VHS widgets. The Photos and My Photos pages are gone; the Wallpaper page embeds only `ArtLibraryPage`.

**Wallpaper library** (../AllSet-personal/docs/wallpaper-import.md)
- `WallpaperSource.library(id)`:
  - videos play from a copy in `originals/` (`--self-contained`); nothing needs the source folder at run time;
  - stills (`LibraryVideo.kind == .image`, a Wallpaper Engine scene's artwork) play from the Mac through `MovingStill` with the photo drift.
- Catalog: `~/Library/Application Support/AllSet/Wallpaper/Library/catalog.json`, written by the importer, which now lives outside the repository (`../AllSet-personal/scripts/wallpaper_library.py`).
- The library folder also holds:
  - `live/`: scene loops, made from the layers by `compose_live()`;
  - `stills/`: scene artwork;
  - `extracted/`: videos taken out of scenes;
  - `transcoded/`;
  - `thumbnails/`;
  - `bin/wetex`: the texture decoder (source in `../AllSet-personal/scripts/wetex.swift`);
  - `scenes.json`: the scene cache. Bump `SCENE_RENDERER` when compositing changes.
  
  3.4 GB in total.
- `WallpaperStore.library`, `libraryURL(id)` (disk check, for playback only) and `canPlay(video)` (no disk access, for cards).
- UI: the `LibrarySection` in My Videos.
- The user's library: **1164 wallpapers** (1006 live, 158 stills) from four Wallpaper Engine folders, self-contained on the Mac, optionally fetched from (and offloaded to) a personal server. Current numbers and rules are in `Documentation/spec.md`; how it works is in `architecture.md`.
  - All **QUARANTINED** (Workshop, no license). Personal use only; never bundle or commit them.
- Scenes left out after review are listed by Workshop id in `SCENE_REVIEWED_SKIP`, each with its reason. To check new scenes, lay the thumbnails out on a contact sheet and look: the preview hash can't tell.

- **Keychain prompts:** never read Keychain at launch. `WallpaperStore.deleteServiceToken` now reads it only when a permanent delete runs; reading at launch asked for the login password after every rebuild (ad-hoc probe builds especially).

**AI Screenshot shortcut** (`Screenshot/ScreenshotShortcutController.swift`, core `ScreenshotShortcut` + `SymbolicHotKeys`): a Carbon hotkey for ⌘⇧5 **also** lets macOS's own toolbar open (both fire), so the controller switches off symbolic hotkey 184 in `com.apple.symbolichotkeys` (CFPreferences + `activateSettings -u`), keeps a UserDefaults marker (`screenshot.systemShortcutOffByAllSet`) and restores it on quit, on another choice, and at the next launch after a crash. Never leave 184 off without the marker. **Testing hotkeys:** synthetic `CGEvent`s don't trigger Carbon hotkeys; use `osascript -e 'tell application "System Events" to key code 23 using {command down, shift down}'`, and a CLI test needs `NSApplication.shared.run()`, not `RunLoop.main.run()`.

**Other areas**
- Wallpaper: `Wallpaper/WallpaperController` (plays only if at least 15% of the screen is uncovered; shared video players).
- Workspace: `Workspace/` (Carbon hotkeys, Accessibility window moves).
- Clipboard: `Clipboard/`.
- Mixer: `Mixer/` (Core Audio taps).
- Knocks: `Knock/` (SPU accelerometer).
- AI screenshot editor: `Screenshot/`.
- Settings: `AllSetCore/Settings/AppSettings.swift`.
- Deep links: `Support/DeepLink.swift` (`allset://open|widget|arrange|fit|theme|focus`).

## Performance lessons (don't relearn these)
- **Never cross-fade two whole pages in SwiftUI** (`.transition` on `.id(page)`): both are re-laid out every frame. `PageVeil` (Core Animation) does the fade; the page swaps at once.
- **`LazyVGrid`/`LazyHStack` build children to measure them.** Give cards exact width and height and put rows directly in one `LazyVStack` (Gallery). `BleedScrollPage` stays an eager VStack (lazy doubled Themes scroll CPU); `PageScaffold` is lazy.
- **System segmented `Picker` costs ~10 ms to build**: use capsule buttons in repeated cards.
- **The main window is released on close** (`MainWindowController.windowWillClose`). A hidden SwiftUI window gets no `onDisappear`, so anything registered in `onAppear` leaks until quit. Don't reintroduce `isReleasedWhenClosed = false` with a kept reference.
- **SwiftUI redraws covered windows.** Desktop widgets must use `WidgetTimeline` (not `TimelineView`), which pauses via `widgetIsOnScreen`. Animated SwiftUI text every second (`.contentTransition(.numericText())`) costs about 10 % CPU: use Core Animation for anything per-second.
- **Caches are `CostCache`** (bytes plus count, LRU). Weigh images with `NSImage.decodedByteCount`. `ImageRenderer` output is 16 bits a channel: convert with `ImageLibrary.displayReady` before keeping.
- **Power and heat limits come from `PerformancePolicy`** (`services.ui.performance`). Add new limits there, never as constants in a subsystem.
- Anything that moves all day uses a Core Animation layer, not SwiftUI animation (5–30% CPU otherwise). Cap `preferredFrameRateRange`: 10–30 fps.
- Don't animate SwiftUI frames or clipShape on big views: RenderBox reallocates surfaces every frame. Animate a Core Animation path instead.
- Keep only the visible content mounted. Give grid cards exact frames; flexible nested stacks measure children many times over.
- No animated blur or shadows; set `shadowPath`. Rasterize layers that only rotate.
- Per-second text changes use `CATextLayer` (`TickingText`), not a SwiftUI `Text` with `.contentTransition`.
- Theme preview cache keys use a content fingerprint and `drawingVersion`: bump `drawingVersion` when preview drawing changes.
- **Drawing a theme preview holds the main thread** (2 s for a busy desktop in a debug build on CI). `ThemePreviewCache` therefore waits while any scroll view is live-scrolled (`NSScrollView.willStartLiveScrollNotification`) and 0.35 s after. A purge (memory pressure) bumps the observed `generation`, which is part of each card's `.task` id, so cards still on screen ask again instead of spinning forever.
- **Liquid Glass only on what doesn't scroll** (`GlassPanel`: the navigation's two capsules, its switches, the Undo toast). Glass on every pill and button tripled scrolling CPU in the probe (warm Themes 9.7% → 43.6%) because glass re-samples what moves behind it; back on the navigation only, 12.6%. Tinted glass also rendered dark over the canvas, so selected and prominent controls are solid white fills.
- **Glass needs something to show.** `GlassPanel` uses `.clear` glass plus a static lit rim (`GlassRim`): `.regular` over a dark picture in dark mode rendered as a solid dark capsule. Heroes darken their top only to 0.32 so the navigation's glass has picture to bend.
- **Motion when opening:** `MainView` cross-fades pages (`.id(ui.page)`, insertion scales from 0.985, 0.32 s); `.entrance(delay:)` (opacity and offset only) staggers a theme's page in; picking a wallpaper dips the hero to dark and fades up (one player, never two). All go through `Motion.resolved`, so Reduce Motion gets plain fades.
- **The backdrop's glows share one strength range** (alpha 0.09–0.13, bell-curve falloff). A small, brighter glow read as a hot spot.
- **Decorative motion in the main window is Core Animation** (`LensGlowView`): the probe showed no idle CPU change with the backdrop moving. Freeze it with `PerformancePolicy.pausesDecorativeMotion` and on window occlusion.
- **AppKit-backed containers ignore SwiftUI safe-area insets**: an `HSplitView` slid under the floating navigation. Use plain stacks under the navigation.
- **Size heroes by their frame, not their media**: `Color.clear.overlay { media }`. A filling picture otherwise grows the stack and pushes the words out of view.
- **Measuring on CI:** a nearly invisible probe window gets App Nap (hold it off with `ProcessInfo.beginActivity`), and a GPU-less VM's window server caps frame gaps near 80 ms on every page; compare CPU and the worst stall, not average frame time.

## Backlog (not started unless the user asks)
- Gallery cards take about 70 ms each to build in a debug build on CI, spread evenly over the widget preview, size picker, chips and button (`-probe galleryparts`): no single fix; a lighter card would be a design change.
- The first visit to Themes after an install or update can still stall once, on a preview already being drawn when scrolling starts.
- **Needs the user's decision:** a seconds clock costs 9–12 % CPU while visible (F15 in the audit). Either move the rolling digits to Core Animation, or let the digits change without rolling.
- Wallpaper library: fast-scroll hitches (33–43 ms) over 1,000 cards; GPU-drawn cards break the hover preview. See ../AllSet-personal/docs/wallpaper-import.md.
- Audit recommendations not done: align decorative frame rates to {10, 15, 30}; lazy calendar store; see `Documentation/perf-audit.md`, Phase 5.
- Audit findings F1–F16 from the Phase 0 report are waiting for the user's "go".
- Later waves: calendar in the notch, a brightness HUD, a menu-bar icon manager, Shortcuts/script live activities.
- Optional: Unsplash, Pexels or Pixabay search, if the user gets an API key.
