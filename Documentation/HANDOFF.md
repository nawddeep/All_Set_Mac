# All Set: Handoff

**Read this first at the start of every session, instead of reviewing the codebase.** It's rewritten at the end of every session. Dated session logs are in `Documentation/Reports/` (newest last). For what the app contains (widgets, themes, pages), see `CONTENT.md`. Only open the source files that the task at hand needs.

_Last updated: 2026-10-06 (audit repairs: read Reports/2026-10-06-audit-repairs.md first; Wallpaper opens directly to the video library; retired Aerial/Art sources and bar removed. Widget spotlight resizes to its footprint; animated size/style controls. Read Reports/2026-10-06-video-library-and-widget-motion.md first; 336 tests.)_

---

## Standing instructions from the user
1. **After every change, rebuild and replace the Dock app:**
   ```sh
   ./scripts/build-app.sh
   osascript -e 'tell application id "com.pratik.allset" to quit'
   open build/AllSet.app
   ```
2. **Optimise at the core level** with every change: CPU, GPU and WindowServer cost. Measure it; don't assume.
3. **Copyright:** themes are *original*, inspired by an era, genre or mood. No logos, album art, promo photos or trademarks. Real people's names may appear only in hidden search tags, never in UI text (a test enforces this). The user's player photos stay on their Mac, never in the repo.
4. **Save tokens:** read this file and the latest report instead of re-reviewing the project. End every session by updating this file and writing a report.
5. Commit or push only when asked (the user has approved commits at each verified checkpoint this session; never push without being asked). The remote is `cloud` → github.com/pratik-aep/all-set-mac-app (`origin` points at a repo that no longer exists).

## Current Widgets and Wallpaper design
- Widgets: `Studio/CinematicWidgets.swift`; Dark default; all 91 catalog entries + 634 themed widgets remain available. Widgets and Wallpaper share the cached Midnight Aurora Themes atmosphere via `StudioThemeStyle.swift`. Every page uses the same `CinemaNavigation`.
- Wallpaper: `Wallpaper/WallpaperPages.swift` → `ClassicWallpaperPage`, always `VideosSection`. No Aerial/Art/My Videos tabs, source bar, Aerial service, unused cinematic replacement, or source-tab state. Search and horizontally scrollable category filters live in the library. Full-bleed hero preserves current desktop media; imported library, import/drop, sorting/Owned filters and details remain. Shared art models remain for Themes/widgets; old Art deep links now open the video library.
- Aerial active data retired into `build/backups/retired-wallpaper-sources-2026-10-06/`: 71 cached manifest/preview files, one Aerial download, one retired preference. Video/server library records remain. `WallpaperCategory` preserves existing catalog JSON categories independently of the deleted Aerial model.
- Spotlight preview, shadow and floor light share the fitted widget footprint and animate size changes. `StudioSegmentedControl` supplies independent sliding highlights for size/style, including Customize, with Reduce Motion support.
- 336 tests / 85 suites, no warnings. Native size/style, direct-library, search recovery and scrolling checks confirmed. All 12 final spotlight renders inspected at 900×600 and 1280×800; opt-in render cases in WidgetRenderHarness wait for page removal before resetting state. Early incorrectly named captures are retained and excluded from passing evidence.
- Warm gallery and library scroll have no >33 ms gaps; first-load runs each have one. Warm gallery CPU 30.8% → 34%, p95 18.4 → 18.3 ms. Whole-Mac GPU/WindowServer counters measured, without an isolated improvement claim. Read the latest report for exact limits and artifacts.
- Exact Dock bundle: `build/AllSet.app`, rebuilt, development-signed and relaunched; identity in `build/review/video-library-widget-motion-2026-10-06/bundle-identity.txt`. Original app backup remains `build/backups/AllSet-before-widgets-wallpaper-2026-10-05.app`. No commit/push.
- Approved design references: `design/widgets-concepts/SELECTED.md`, `design/wallpaper-concepts/SELECTED.md`; previous unified visual style report remains `Reports/2026-10-06-unified-studio-theme-style.md`.

## Outside the repo (set up 2026-10-02)
- Claude Code has `ponytail@ponytail` (github.com/DietrichGebert/ponytail, MIT, hooks reviewed: local files only) enabled in `~/.claude/settings.json`, default level full; `/extension [status|on|off|lite|full|ultra]` (`~/.claude/commands/extension.md` → `~/.claude/ponytail-ctl.js`) shows and switches it. Needs a new session to load. Ponytail means: simplest working code, no unrequested abstractions.
- `.claude/settings.local.json` (git-ignored) allows routine build/test/git commands and denies `git push`, `rm -rf`, `git reset --hard`, `sudo` (a compound command containing `rm -rf` is refused).
- Testing hotkeys: synthetic `CGEvent` doesn't trigger Carbon hotkeys; use System Events `key code`. Driving the pointer: see the scratchpad `mouse` tool notes in the 2026-10-01/02 sessions (refuses to click unless an All Set window is topmost).

## Machine quirks
- The first `python3` on PATH is an empty file that prints nothing: use `/opt/homebrew/bin/python3`, or awk, grep or perl.
- zsh doesn't split words: use arrays or `${=var}`.
- Screenshot file names contain a narrow no-break space: use globs.
- `sed` has no `\b`: use perl.
- Perl `s{}{}` breaks on Swift code full of braces: use the Edit tool.
- macOS has no `timeout` command.
- M4 MacBook Air: fanless, screen 1470×956 pt (2940×1912 px), 16 GB.
- Signing identity "All Set Development" is in the login keychain; `build-app.sh` uses it so permissions survive rebuilds.

## Build, test, verify
| What | Command |
|---|---|
| Debug build (expect 0 warnings) | `swift build 2>&1 \| grep -c warning:` |
| Tests (currently 336 in 85 suites) | `swift test` |
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

**Scratchpad helpers** (session temp directory; they may be gone): `sheetL out.jpg cols files…` makes a contact sheet (sizes from the `CW`/`CH` environment variables); `load.sh` reads WindowServer load.

**Profiling:** `xctrace record --template 'Time Profiler' --attach <pid> --time-limit 60s --output x.trace`, then `xctrace export --input x.trace --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' > x.xml`, then aggregate with `/usr/bin/python3` (the Homebrew python lacks expat) using the scratchpad `perf/agg.py`, `stacks.py` and `main.py`. The "CPU Profiler" template records nothing on this Mac; use "Time Profiler". `xctrace --launch` can leave a copy stopped at dyld (state `T`): check `ps -o stat` and kill it. `leaks <pid>`, `heap <pid>` and `footprint <pid>` work without sudo; `powermetrics` needs sudo (not available).

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
- **Theme widgets in the gallery:** `ThemeWidgetCatalog` (core) currently flattens 634 themed widgets, repeats removed by an encoded fingerprint; setup fonts and corners are copied onto each instance. `CinematicCatalog` includes them in the main scroll and in purpose/search results; `ui.galleryFromThemes` selects only themed entries. `ThemeWidgetGallery.swift` retains the original card/Add/drag behavior.
- **Text options on every widget** (`WidgetOptions.font`, `cornerRadius`, `textCase`, `renamedText`, `footnote`, `footnoteStyle`). Built-in labels go through `WidgetWord(...)` (`Widgets/Design/WidgetWord.swift`), which shows the rename and reports the original via `WidgetWordsKey`; the inspector's preview collects those, so the editor lists exactly the words on screen. New fixed labels in widgets should use `WidgetWord`, not `Text`. The caption draws in the window's bottom margin, so it never needs a slot.
- Views live in `AllSet/Widgets/Kinds/*.swift`. `WidgetHostView.swift` has the kind → view switch and `WidgetSurface`. `DesktopWidgetController` manages the desktop windows, scaled by `settings.widgetScale` (0.7–1.6).
- Motion goes through `Components/LiveLayers.swift`. `LiveLayerView` subclasses run Core Animation loops at capped frame rates and stop when covered or when Reduce Motion is on. Each one also draws a still SwiftUI version for snapshots (`widgetSnapshot` environment value). Building blocks:
  - `LiveArtwork`: float, shine and glow, cached in `ArtworkCache`.
  - `PulsingGlow`, `Sparkles`, `BlinkingLight`, `EqualizerBars`.
  - `TwinkleLayer`, `AuraLayer`, `FlameLayer` and `SpiralLayer`, in `MysticWidgets.swift`.

**To add a widget kind:**
1. `WidgetModels`: the case, category, title, symbol, summary, keywords, sizes, `isFreeform`, `paintsOwnBackground`, `defaultSize` and defaults switch.
2. An entry in `WidgetCatalog`.
3. A view, plus a case in the `WidgetHostView` switch.
4. `WidgetOptionsEditor`: its section and `showsStylePicker`.
5. The `looks` list in `WidgetStudio`.

**Search and photos**
- `AllSetCore/Aesthetics/PhotoSearch.swift` searches Wallhaven and Openverse in parallel.
- `Wallhaven.swift`: SFW only (`purity=100`), about 45 requests a minute, multi-word names in quotes.
- `Search/WallpaperQuery.swift`: aliases, exclusions, pop-culture detection, and aesthetic → Wallhaven tag or Openverse only.
- `Search/AestheticSearch.swift`: aesthetic vocabulary and spelling.
- Openverse allows at most `page_size` 20 for anonymous requests; more returns a 401.
- The UI is `Studio/LibraryPages.swift` (`WebPhotosPage`, `SearchFilters`, `RecentSearches`), reached only through `LibraryPicker`, the picture picker of Photo, Polaroid and VHS widgets. The Photos and My Photos pages are gone; the Wallpaper page embeds only `ArtLibraryPage`.

**Wallpaper library** (docs/wallpaper-import.md)
- `WallpaperSource.library(id)`:
  - videos play from a copy in `originals/` (`--self-contained`); nothing needs the source folder at run time;
  - stills (`LibraryVideo.kind == .image`, a Wallpaper Engine scene's artwork) play from the Mac through `MovingStill` with the photo drift.
- Catalog: `~/Library/Application Support/AllSet/Wallpaper/Library/catalog.json`, written by `scripts/wallpaper_library.py import <folder>` (needs Homebrew ffmpeg; run with `/usr/bin/python3`). The importer is idempotent, with IDs from SHA-256.
- The library folder also holds:
  - `live/`: scene loops, made from the layers by `compose_live()`;
  - `stills/`: scene artwork;
  - `extracted/`: videos taken out of scenes;
  - `transcoded/`;
  - `thumbnails/`;
  - `bin/wetex`: the texture decoder, compiled from `scripts/wetex.swift`;
  - `scenes.json`: the scene cache. Bump `SCENE_RENDERER` when compositing changes.
  
  3.4 GB in total.
- `WallpaperStore.library`, `libraryURL(id)` (disk check, for playback only) and `canPlay(video)` (no disk access, for cards).
- UI: the `LibrarySection` in My Videos.
- The user's library: **1164 wallpapers** (1006 live, 158 stills) from four Wallpaper Engine folders, self-contained on the Mac, optionally fetched from (and offloaded to) a personal server. Current numbers and rules are in `Documentation/spec.md`; how it works is in `architecture.md`.
  - All **QUARANTINED** (Workshop, no license). Personal use only; never bundle or commit them.
- Scenes left out after review are listed by Workshop id in `SCENE_REVIEWED_SKIP`, each with its reason. To check new scenes, lay the thumbnails out on a contact sheet and look: the preview hash can't tell.

**Lid Plane** (`AllSet/LidPlane/`, `AllSetCore/LidPlane/`; System → Lid Plane): Jhey's lid-fold effect, GPL-3.0-or-later (notices in `Documentation/third-party/`; **distributing All Set means distributing it under the GPL**, fine for personal use). Core: `LidSensor` (IOHID lid angle, read-only), `AutoAnchor`, `LidMotionFilter`, `AngleActivation`, `CaptureDemand`, `DisplaySafetyGate`, `LidPlaneSettings` (UserDefaults `lidplane.*`), tested in `LidPlaneTests`. App: `LidPlaneController` (while the fold is live: a `CADisplayLink` on the built-in screen, 60–120 Hz, hinge read ≤ ~80×/s; enabled at rest: 10 Hz timer; `LidTracker` tracks the hinge 1:1 like a touch (alpha-beta filter on the whole-degree readings + velocity-fed smoother; ~0.8° from the true lid on a normal close, flat by the time an opening lid passes the angle, so no resize when it hides); `CaptureWarmup` starts the stream within 15° above the activation angle, or 0.6 s ahead at the measured speed (≤ 60°), while the lid moves; `FoldIntro` eases the fold in from flat (smoothstep, 0.3–0.8 s by gap) only when capture was late; `OverlayVisibility` dissolves the overlay over the first 1.5° of fold both ways, so start and end are seamless; capture is native pixels (`CGDisplayCopyDisplayMode`, not `CGDisplayPixelsWide`, which is points) in Display P3 with the MTKView tagged to match; 5 Hz readout while the page is open; none otherwise), `LidPlaneRenderer` (Metal, shader inline; blur levels at ½–1/16 size, rebuilt only when the picture changes: 1.4 ms GPU per 2560×1600 frame, was 3.7), `LidPlaneCapture` (ScreenCaptureKit, 60 fps), `LidPlanePage`. Differences from upstream: the stream excludes only the overlay **window** (upstream excludes its whole app, which would drop All Set's own wallpaper and widgets), and the overlay stays ordered in at alpha 0 while a stream runs so it can be found; shortcuts use `HotKeyCenter` with a `lidplane` group (window snapping's `unregisterAll()` now only drops its own group). Preserve upstream's safety rules (never fall back to an external display, wait 0.5 s of stable display before restarting capture, raw angle above the limit always hides). `-renderLidPlane dir` renders previews and runs the renderer checks. **Not verified by me:** a live capture with the effect on (needs All Set's own Screen Recording approval and a physical lid).
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

## Latest review (2026-10-05): Five quick Themes passes
- User requested five quick review passes, then their decision before a deeper round. No implementation edits in this round. Wallpaper work is deferred until Themes is complete.
- Fresh results: 25 targeted tests / five suites and 30 native carousel/cache checks pass; all eight top/scrolled captures across four window sizes inspected. Scroll sample: 48.1–48.5% app CPU, p95 17.9–18.1 ms, zero >33 ms hitches. System-wide WindowServer 49.4%; no isolated GPU measurement or comparative improvement claim.
- Visual match remains partial: softer cyan light/faint reflection, denser previews, Moodboards below the initial fold, caption collisions/placeholder artwork, and a slightly cropped last shelf card.
- Live arrows, Football/All and Aurora pagination work. Matching typed search returns one result, but query replacement was inconsistent in automation. Window visibility/focus changed during the checks; treat search as unresolved verification, not a proven app defect. Clear search restored browsing.
- Exact Dock bundle signature and executable code verified against release. Report and raw evidence: `Reports/2026-10-05-themes-five-pass-review.md`, `build/review/themes-five-pass/`. Side-by-side PNG: `reference-vs-current.png`; actual Dock capture: `live-dock-app.png`.
- Current source checkpoint is the user's `80dae18`. No new commit/push. Preserve existing user edits and Wallpaper concepts.

## Latest design request (2026-10-05): Wallpaper selected; Widgets previews
- User explicitly chose **Immersive Cinema** for Wallpaper only. This is the sole selected Wallpaper direction: `design/wallpaper-concepts/2026-10-05-v2/03-immersive-cinema.png`. Durable selection notes: `design/wallpaper-concepts/SELECTED.md`.
- Preserve the alpine twilight full-window preview, floating navigation, compact Aerial Videos / Art / My Videos selector/search, lower caption/actions and bottom filmstrip. Other Wallpaper concepts were not selected.
- Current request is to generate a matching Widgets concept before designing/implementing the two frontends together later. Generate previews only at this checkpoint; no app source or Dock bundle changes requested.
- Original Wallpaper previews and prompts: `design/wallpaper-concepts/2026-10-05/`; fresh variants and exact prompts: `design/wallpaper-concepts/2026-10-05-v2/`. Widgets selection is pending.

## Current state (2026-10-05): Themes toolbar and smoothness
- User asked to fix the odd nested filter bar and optimize Themes. A single 48 pt toolbar now uses plain inactive labels, one selected pill and integrated search. Narrow windows have a category overflow menu and edge fade; search and category access remain fixed above scrolling content.
- Scroll layout is one eager stack with lazy horizontal rails; no pinned-header LazyVStack. Category/search mode changes reset the relevant content offset. Each preview has a separate observable entry; unrelated image arrivals no longer invalidate all cards. Only two adjacent desktops are prewarmed. Carousel remounting no longer steals search focus.
- Latest verification: 312 tests / 85 suites, 30 native carousel/cache checks, warnings-as-errors builds, four window sizes with scrolling. Interleaved before/after/after/before: app CPU mean 47.2% → 43.1% (~9% lower), p95 20.6–25.1 → 18.2–20.2 ms, zero >33 ms hitches in both. WindowServer 39.2–39.6% → 40.5–40.8%, system-wide; no isolated GPU or WindowServer improvement claim.
- Exact Dock bundle `build/AllSet.app` rebuilt, signed and relaunched on Themes. Installed code section matches release. Previous cinematic bundle backed up at `build/backups/AllSet-before-toolbar-refinement-2026-10-05.app`. Art remains bundled offline. Desktop apply/preview controls were not activated.
- Read `Reports/2026-10-05-themes-toolbar-smoothness.md`; artifacts are in `build/review/themes-refinement/`. Earlier design implementation: `Reports/2026-10-05-themes-cinematic-design.md`. Existing 12-widget Midnight Aurora and cinematic carousel/shelves remain.
- Local work only, no commit or push. Preserve the user's unrelated edits. Other tabs await the user's next frontend instruction; engineering review is separate.

## Previous state (2026-10-05): Themes hero redesign, H0-H2 done
- **Pushed** to `cloud` main and `perf-audit` (`d6c4512`): looping 3:4 carousel in a glass panel (search, category rail, indicator, arrows), pre-rendered card art and `CardHalo` halos, `ThemeAccent` per theme with fallback (theme accent, then wallpaper colour, then warm gold), A/B-crossfaded `ThemeAtmosphere` (static layers, blurred `.backdrop` previews), tighter shared nav (`FloatingNav`, 100 pt, solid scrim), `scripts/review-hero.sh` (`make review`) and `docs/UI-Spec.md` (every measurement). 313 tests, 0 warnings. Code lives in `Sources/AllSet/Studio/Themes/` and `AllSetCore/Themes/`.
- **Plan** (the user's "v2" prompt, chat only): H3 card lighting (neon edge strip, ground glow, sheen, neighbour rims) · H4 glass borders, separate category pills, one grain tile · H5 composition (neighbour gap 8-12 pt, dim ~0.1/0.3, cards cut to title + 1 centre + 2 small, hand-pick all 8 with a contact sheet, replace watermarked Americana/Albiceleste wallpapers) · H6 motion, Reduce Motion, Instruments · H7 final match at 1400x900 + wide + narrow. One phase at a time; view `docs/reference/concept2-reference.png` first and regenerate `build/review/reference-vs-now.png` after each; stop at each gate.
- **Open perf:** atmosphere costs ~5 points of scroll CPU (42-43% vs 37-38% on HEAD, p95 and hitches equal); warm Themes switch 96-137 ms vs 84-123. A `.drawingGroup()` flattening test was never run (the temp code is removed). Measure against a HEAD build (`-probe scroll|pageswitch`, `ONLY=themes`).
- Not committed on purpose: `scripts/cloud/catalog_service.py` (404 fix), stray root PNGs, `hero theme.md`.

## Previous state (2026-10-03)
- **Shipped and pushed** to `cloud` main and `perf-audit` (`0191b97`): Home, Collections and Art tabs removed (Art lives on the Wallpaper page; `allset://page/art` opens it there); the logged runtime errors fixed; page builds deferred (`Deferred`); aerial, clipboard and My Photos thumbnails decoded off the main thread; theme previews no longer wiped by other builds. 293 tests, 0 warnings.
- **Not taken:** the overnight redesign (`redesign/ui`, local only, unpushed). Its analysis and report are in `REDESIGN_REPORT.md` / `DECISIONS.md` on that branch.
- **Open:** Gallery scroll hitches (p95 33–38 ms, 14–21 dropped frames a pass, live widget previews); Island and Gallery pages take ~100 ms to open; Island tab switches lose 15–38 ms (re-measure with the Dock app quit). See `Reports/2026-10-03-wrap-up.md`.
- Git: push to `cloud`, not `origin` (dead URL): `git push cloud perf-audit:main perf-audit:perf-audit`.

## Previous state (2026-10-02)
- **In progress: a 7-step request** (in order): 1 widget snap grid, drag, right-click menu ✅; 2 every theme's widgets in the gallery + editable labels inside widgets and an optional caption below ✅; (extra, asked mid-way) Lid Plane tab ✅; 3 AI Screenshot on ⌘⇧5 ✅ (replaces the system shortcut, restored on quit); 4 analyse this Mac (hardware, sensors, permissions) and adapt; 5 measure and fix choppiness everywhere; 6 window UI toward the user's "Wallspace" reference (big featured hero, filmstrip, curated rows); 7 Island Notes tab: alarms, stopwatch, daily routines with notifications.
- Done since: Lid Plane tab (`0626efc`), AI Screenshot ⌘⇧5 (`bf59f1f`). Remaining: 4, 5, 6, 7 above, in that order.
- Step 1 verified in the real app (seeded layout tidied to the predicted slots, Arrange-mode drag landed in the predicted slot with the overlay showing, right-click menu, Remove). **Not yet seen working by a person:** dragging a gallery card onto the desktop, and dragging a widget straight off the desktop outside Arrange mode (the desktop was covered by the user's windows; synthetic clicks pass through the island panel, so don't drive the pointer near the notch).

## Earlier state (2026-10-01)
- `main` is at `e92ba9e`: the main-window redesign (design system, floating navigation, every page rebuilt), merged.
- Branch **`claude/festive-brown-ks0f3c`** is 7+ commits ahead of `main`, not yet merged: the navy backdrop with drifting blue light, full-bleed heroes on Wallpaper/Themes/Art, theme previews waiting while scrolling, and the `scroll`/`galleryparts` probes with the CI `probe` job. CI green: 0 warnings, 239 tests.
- Session logs: `Documentation/Reports/2026-10-01-ui-redesign.md` (this redesign), earlier ones beside it. The September performance audit is in `docs/perf-audit.md`.
- **Not yet seen by a person on a real Mac:** the backdrop's motion (CI only captures stills), the Island page's interactive header (pills and try-it buttons inside a form section header), and the redesigned Library with real wallpapers (CI has no catalog).

## Backlog (not started unless the user asks)
- Gallery cards take about 70 ms each to build in a debug build on CI, spread evenly over the widget preview, size picker, chips and button (`-probe galleryparts`): no single fix; a lighter card would be a design change.
- The first visit to Themes after an install or update can still stall once, on a preview already being drawn when scrolling starts.
- **Needs the user's decision:** a seconds clock costs 9–12 % CPU while visible (F15 in the audit). Either move the rolling digits to Core Animation, or let the digits change without rolling.
- Wallpaper library: fast-scroll hitches (33–43 ms) over 1,000 cards; GPU-drawn cards break the hover preview. See docs/wallpaper-import.md.
- Audit recommendations not done: align decorative frame rates to {10, 15, 30}; lazy calendar store; see `docs/perf-audit.md`, Phase 5.
- Audit findings F1–F16 from the Phase 0 report are waiting for the user's "go".
- Later waves: calendar in the notch, a brightness HUD, a menu-bar icon manager, Shortcuts/script live activities.
- Optional: Unsplash, Pexels or Pixabay search, if the user gets an API key.
