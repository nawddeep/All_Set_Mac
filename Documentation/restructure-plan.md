# File layout restructure: plan

_Status: **approved 2026-10-15** (decisions in section 8). No file has been moved yet; the moves start with the Phase 2 prompt. Written 2026-10-15._

The change only moves and renames files, within their current SwiftPM target. No type, function, property or access modifier changes. Type renames are listed in [rename-proposals.md](rename-proposals.md) for a later change.

**Labels.** **[R]** means read in the source or command output. **[I]** means inferred from what was read, not verified line by line. **[NC]** means not checked.

## 1. Baseline (Step 1)

| Command | Result |
|---|---|
| `git rev-parse HEAD` | `4cbf666a8bac6bbfe842242ad297468e8085f9d9` on branch `restructure/file-layout` [R]. This is `main` (`325c7937`) plus one commit that adds the earlier draft of this plan and `rename-proposals.md`. No source file differs from `main`. |
| `git status --short` | Empty: the tree was clean [R] |
| `swift build` (after `swift package clean`, so every file compiled) | `Build complete! (28.83 secs)`, `grep -c "warning:"` = **0** [R]. An incremental build gave 0.47 s and also 0 warnings, but compiled almost nothing, so the clean build is the baseline. |
| `swift test 2>&1 \| tail -15` | `✔ Test run with 432 tests in 100 suites passed after 3.024 seconds.` **432 tests, 100 suites, 0 skipped** (`grep -c skipped` = 0) [R]. XCTest: `Executed 0 tests`. |
| `scripts/check-repo-hygiene.sh` | `Repository hygiene: 399 tracked files, nothing out of place.` exit 0 [R] |
| `git ls-files \| wc -l` | **399** [R] (397 on `main` plus the two plan docs) |
| Toolchain | Apple Swift 6.4 (swiftlang-6.4.0.34.1), Xcode 27.0 (27A266a), arm64-apple-macosx27.0.0 [R] |
| `-renderPages` image set | **NOT RUN:** it isn't in Step 1, and it opens the app's windows. It's planned as the first action of Phase 2 (the moves), before any file moves. |
| Python tests (`scripts/`, `scripts/cloud/`) | **NOT RUN:** not in Step 1, and they need Postgres. No moved file is imported by them [R]. |

The file counts per folder are in [Appendix B](#appendix-b-count-check-against-git-ls-files), next to the number of files that move.

## 2. The ten known problems: confirmed or refuted

| # | Verdict | Evidence |
|---|---|---|
| 1 | **Confirmed** [R] | Design code is in `Components/` (7 files), `Design/` (6), `Widgets/Design/` (4) and `Studio/StudioThemeStyle.swift`. One correction: 2 of the 6 files in `Design/` aren't design code. `AppNavigation` switches over `AppPage`, and `SearchOverlay` is the ⌘K search; both are the app shell. |
| 2 | **Confirmed** [R] | 45 non-test types plus 10 test suites have "Theme" in the name. They cover **5 distinct concepts**; see section 4. |
| 3 | **Partly refuted** [R] | `Aesthetics/` isn't wallpaper code. `ImageLibrary`, `ImageSource`, `CuratedBackgrounds` and `ArtPiece` are used by widgets, `WidgetTheme*`, `ThemeSet` and Wallpaper alike. `Studio/LibraryPages.swift` isn't wallpaper either: it's the Art / Photos / My Photos picker (`LibraryPicker`) that `WidgetOptionsEditor.swift` opens at lines 75, 668, 730 and 828. Wallpaper code proper is in exactly two folders: `AllSetCore/Wallpaper` and `AllSet/Wallpaper`. |
| 4 | **Partly confirmed** [R] | `Studio/` mixes the Themes page with the widget gallery and editor. It has no wallpaper pages (see #3). |
| 5 | **Confirmed** [R] | Of the 19 files, 10 hold widgets that do different things, for example `SystemWidgets` (system, battery, now playing, note). |
| 6 | **Confirmed, naming only** [R] | The two files hold different types in different modules: Core's has `ScreenshotStudio` and `ScreenshotAI`; the app's has `ScreenshotStudioController`, `ScreenshotStudioView` and `ScreenshotPage`. They compile today. The problem is confusion, not a build error. |
| 7 | **Partly refuted** [R] | `Support/` has **19** files, not 22. They fall into six clear purposes plus `DeepLink`. `DeleteAPIKeychain` is *not* misplaced: its only user is `WallpaperStore`, and it follows the feature-local pattern of `GitHubKeychain` and `AIKeychain`, all built on `KeychainItem`. |
| 8 | **Confirmed** [R] | All three files are `#if DEBUG` from first line to last. `AppDelegate.swift` calls them only inside `#if DEBUG` blocks (lines 25–30 and from 32). `CarouselProbe.swift` is an `extension PageCPUProbe`. |
| 9 | **Confirmed** [R] | Docs are in `Documentation/` and `docs/`, plus `rules_frontend.md` and `CONTENT.md` at the root, plus a root `design/` folder of concept images that the brief didn't mention. `architecture.md` is titled "Wallpaper Library: architecture" and says "Last updated: 2026-10-03". It isn't an app-wide map. Whether its wallpaper content is out of date: [NC]. |
| 10 | **Confirmed, with corrections** [R] | The test folder is flat, with **44** files, not 41. Five of them test several unrelated areas, with no area covering half the file: `LogicTests`, `NotesAndPDFTests`, `ThemesAndSearchTests`, `WidgetTests` and `WidgetNetworkTests`. `HardeningTests` is 94% `StoreFileTests`. |

## 3. Path dependencies (Step 3), and the fix each needs

| Hit | What it depends on | Fix | Risk |
|---|---|---|---|
| `Tests/AllSetCoreTests/LiveSystemTests.swift:49` | `#filePath` with three `deletingLastPathComponent()` calls to reach the repo root, then `.build/debug/<helper>` [R] | **Don't move this file.** One folder deeper, `helperURL` would be nil, and `.enabled(if: helperURL != nil)` would quietly *skip* the test rather than fail it. The skipped count (0 today) is the check. | high if moved, so it isn't |
| `Sources/AllSetCore/Aesthetics/ImageLibrary.swift:606-608` | `Bundle.main` (inside the .app) or `Bundle.module`, `subdirectory: "ThemeArt"` [R] | None needed. `Bundle.module` is chosen by the *target*, not the source folder, and `.copy("Resources/ThemeArt")` is relative to the target root, which doesn't move [R]. Verify after the move with `ThemeLibraryTests` and the theme cards in `-renderPages`. | **high** (resource lookup) |
| `Sources/AllSetCore/Widgets/StudioDiscovery.swift:116-117` | Same `ThemeArt` lookup [R] | The file doesn't move. | — |
| `Package.swift:17,22,33,38,44` | Each target is a whole folder; `resources: [.copy("Resources/ThemeArt")]` [R] | None: target roots and `Resources/` don't move. | low |
| SwiftPM rule [I] | Two files with the same name in one module fail to compile | A script checked the full move list: no target ends up with a duplicate file name [R]. | low |
| `scripts/build-app.sh:37` | `cp Documentation/third-party/*` [R] | `third-party/` stays. | — |
| `scripts/build-app.sh:63` | `cp -R Sources/AllSetCore/Resources/ThemeArt` [R] | Doesn't move. | — |
| `scripts/review-hero.sh:7,39` | `docs/reference/concept2-reference.png` [R] | Change both to `Documentation/design/reference/concept2-reference.png`, **in the same commit** as the image move. | med |
| `design/widgets-concepts/2026-10-05/asset-manifest.json:3-4` | Repo-relative `design/...` paths [R] | Prefix both with `Documentation/` in the same commit. Lines 8+ are absolute paths from another machine (`/Users/pratiksmac/...`); they're history and stay as they are. | med |
| `scripts/wallpaper_library.py:460,1342` | Comments citing `docs/wallpaper-import.md` [R] | Change the comment text to `Documentation/wallpaper-library/import.md`. No code change. | low |
| `scripts/cloud/migrations/0001_initial.sql:4` | Comment citing `Sources/AllSetCore/Wallpaper/WallpaperLibrary.swift` [R] | That file doesn't move, so the migration isn't touched. | — |
| `scripts/probe-budgets.json:13` | Text "see Documentation/HANDOFF.md" [R] | `HANDOFF.md` stays. | — |
| `scripts/check_probe_budgets.py:62` | Finds `probe-budgets.json` next to itself [R] | `scripts/` doesn't move. | — |
| `scripts/check-repo-hygiene.sh` | Patterns only: build folders, `*.env`, `.p12`, `.mobileprovision`, `.DS_Store`, files over 5 MB [R] | None; moves can't change any of these. | — |
| `.github/workflows/ci.yml`, `release.yml`, `Makefile`, `.vscode/*` | No `Sources/`, `Tests/` or doc paths; only `scripts/*` and `.build/debug/AllSet` [R] | None. | — |
| `AppDelegate.swift` → `WidgetRenderHarness`, `PageCPUProbe` | Called by type name inside `#if DEBUG` [R] | None. Same target, so the names resolve wherever the files sit. These drive CI's `screenshots` and `probe` jobs, so they're verified by `-renderPages` and `-probe`. | med |
| `README.md:5,62-90` | Link to `Documentation/operations.md`; a source tree diagram [R] | Rewrite the link and tree in the path-update phase (P11). | low |
| `Documentation/HANDOFF.md` (lines 3, 29, 96, 116, 157, 174, 178, 226, 229, 240, 241, 259, 266, 267) | Source folders, `docs/*`, `design/*`, `CONTENT.md` [R] | Update each path in P11. | low |
| `CONTENT.md:146`, `docs/perf-audit.md` (14 lines), `docs/wallpaper-import.md:3,290-292`, `docs/UI-Spec.md:159`, `Documentation/report.md:20,41`, `Documentation/architecture.md:29,32,75`, `Documentation/audit-2026-09-29.md:29,64` | Source and doc paths in prose [R] | Update in P11. Exception: in `perf-audit.md`'s list of changed files and `audit-2026-09-29.md`'s evidence lines, the old path records history, so P11 adds the new path next to it rather than replacing it. | low |
| `Documentation/Reports/*` (67 lines) | Absolute links into another checkout (`/Users/nawdddep/Downloads/all-set-mac-app-main/...`) or relative links [R] | Not edited. They're dated snapshots, and the absolute links are already dead. | — |
| App code reading docs at runtime | Searched for `"…Documentation…"`, `"docs/…"`, `"design/…"` string literals: none [R] | — | — |
| Tests reading source files or file names | Only `LiveSystemTests.swift:49` [R] | See the first row. | — |

## 4. The "Theme" question (Step 4)

There are **five distinct concepts** [R, from each type's doc comment]:

| # | Concept | Types (file) | Layer |
|---|---|---|---|
| C1 | **Colour constants for the app's own UI** ("Metric colors, tuned to read on the black notch", sticky-note paper, the widget Solid/Color gradients) | `Theme` (`AllSet/Components/Theme.swift`) | App UI: notch, menu bar, mixer, notes, widgets |
| C2 | **The widget design language**: how any widget's card, colours, type, accent and shadow are drawn ("Widgets render through the theme instead of styling themselves") | `DesignTheme`, `ThemePalette`, `ThemeTypography`, `ThemeWeight`, `ThemeShadow` (`AllSetCore/Widgets/DesignTheme.swift`); `ThemedShadow` applies it (`AllSet/Widgets/WidgetHostView.swift`) | Core model, app widget rendering |
| C3 | **The original desktop setups**: a whole desktop look plus a starter "kit" of widgets; the four extension files are the packs | `WidgetTheme` (`AllSetCore/Widgets/WidgetTheme.swift` + `+Cinematic`, `+Colour`, `+Fandom`, `+Moodboards`) | Core model, used by `ThemeSet`, `ThemeLibrary`, `WidgetStudio`, `AppServices` |
| C4 | **Theme sets**: the product the Themes page offers ("A complete theme world"). A set's `Look` is either a C2 `DesignTheme` or a C3 `WidgetTheme`. | Core: `ThemeSet`, `ThemeCollection`, `ThemeResearch`, `ThemeLibrary`, `ThemeStats`, `ThemePhotos`, `ThemeAccent`, `ThemeCardArt`, `ThemeCarouselLayout`, `ThemeCarouselDepth`, `ThemeWidget`, `ThemeWidgetCatalog`. App: `ThemePreview`, `ThemeInstall` (`AppServices+Themes.swift`), `ThemePreviewBar` (`WidgetHostView.swift`), plus 21 Themes page types: `ThemesPage`, `ThemeDiscovery`, `ThemeSetCard`, `ThemeSnapshot`, `ThemeDetailPage`, `ThemeComposition`, `ThemeWallpaper`, `ThemeCardComposition`, `ThemePreviewVariant`, `ThemePreviewCache`, `ThemeWidgetRails`, `ThemeWidgetCard`, `ThemesMotion`, `ThemeAtmosphereState`, `ThemeAtmosphere`, `ThemePreviewCard`, `ThemeRail`, `ThemeMoodboards`, `ThemesFilterBar`, `ThemeHeroState`, `ThemesHero` | Core model, app Themes feature |
| C5 | **A wallpaper colour watcher**: "Keeps what themes need from the outside world: the color of the desktop picture" | `ThemeManager` (`AllSet/Widgets/Design/WidgetStyle.swift`) | App widget style |

The type counts are 1 + 6 + 1 + 36 + 1 = 45 [R]. The 10 test suites named `*Theme*` test C2, C3 or C4.

**Files named `*Theme*`, and a clearer file name for each.** The rule is "a file is named after its primary type", so a file can't get a clearer name unless its type is renamed. That would be a type rename, which this prompt rules out. Only one file name is wrong on its own terms.

| File | Concept | Proposed file name | Why |
|---|---|---|---|
| `AllSet/Studio/StudioThemeStyle.swift` | none (holds no theme) | **`StudioAtmosphere.swift`**, in this change | No type is named `StudioThemeStyle`. The file holds `StudioAtmosphere`, `StudioFilterSurface` and `StudioSegmentedControl`. |
| `AllSet/Components/Theme.swift` | C1 | Keep; becomes `Design/Tokens/Theme.swift` | Matches `enum Theme`. A clearer name needs the type rename `Theme` → `AppPalette` (in rename-proposals). |
| `AllSetCore/Widgets/DesignTheme.swift` | C2 | Keep | Matches its type. Rename proposal: `WidgetDesign`. |
| `AllSetCore/Widgets/WidgetTheme.swift` + 4 extensions | C3 | Keep the names; **move to `AllSetCore/Themes/`** | Matches its type. Moving it separates C3 from C2, which share `Widgets/` today. Rename proposal: `DesktopSetup`. |
| `AllSet/Widgets/Design/WidgetStyle.swift` (holds C5) | C5 | Keep | Its primary type is `WidgetStyle`. Rename proposal: `ThemeManager` → `WallpaperAccentMonitor`, in its own file. |
| `AllSet/AppServices+Themes.swift` | C4 | Keep | Follows the `Type+Topic` extension convention. |
| `AllSet/Studio/ThemesPage.swift`, `ThemePreviews.swift`, `ThemeWidgetGallery.swift`, `Studio/Themes/*` (5 files named `Theme*`) | C4 UI | Keep the names; move to `Features/Themes/` | The names already describe the Themes page; the folder then names the feature. |
| `AllSetCore/Themes/Theme*.swift` (8 files) | C4 | Keep | Already together and matching their types. |
| `Tests/.../ThemeCarouselLayoutTests`, `ThemeLibraryTests`, `ThemeWidgetCatalogTests` | C4 | Keep; move to `Tests/.../Themes/` | — |
| `Tests/.../ThemesAndSearchTests.swift` | C3/C4 + imagery + widgets | Keep at the test root | Mixed file; a split is proposed. |

## 5. Target layout (Step 5)

```
Sources/AllSet/
  App/                 AllSetApp, AppDelegate, AppServices(+Themes), MainWindow, AppNavigation, SearchOverlay, MenuBar/
  Design/
    Tokens/            DesignTokens (DS), Theme
    Motion/            Motion, DriftingImage, LiveLayers
    Components/        Components, DesignComponents, CinemaDesign, LayerGauges, KeyboardActivatable
    Backdrop/          WindowBackdrop, StudioAtmosphere
    Widget/            WidgetStyle, WidgetComponents, DesignSurface, WidgetWord
  Features/
    Clipboard Knock LidPlane Mixer Notch Notes Screenshot Settings Workspace Wallpaper
    Themes/            Themes page (flat: page, previews, hero, rails, atmosphere)
    Widgets/           host: DesktopWidgetController, WidgetHostView, WidgetWindow, WidgetGridOverlay, Backgrounds, ArtShader, ArtView
      Studio/          GalleryPage, CinematicCatalog, WidgetStudio, WidgetOptionsEditor, LibraryWidgetPreview, LibraryPages
      Kinds/           CinematicWidgetFace + Time/ Calendar/ Focus/ System/ Weather/ Developer/ Music/ Sports/ Decor/
  Debug/               PageCPUProbe, WidgetRenderHarness, CarouselProbe (unchanged, each #if DEBUG)

Sources/AllSetCore/
  Clipboard Knock LidPlane Mixer Notch Notes Screenshot Settings Themes Wallpaper Widgets Workspace  ← same 12 names as Features/
  Calendar Developer Media Power Weather System    data sources the widgets and notch read (no UI feature of their own)
  Imagery/             was Aesthetics/ + Search/AestheticSearch + Search/WallpaperQuery
  Support/             Storage/ Security/ Concurrency/ Performance/ Text/ Display/ + DeepLink.swift
  Resources/ThemeArt   unchanged

Tests/AllSetCoreTests/
  Clipboard Imagery Knock LidPlane Mixer Screenshot Support System Themes Wallpaper Widgets Workspace
  root: TestEnvironment, LiveSystemTests (#filePath) and the 5 mixed files

Documentation/
  README.md (new index)  architecture.md (new app map)  HANDOFF.md  UI-Spec.md  perf-audit.md
  frontend-rules.md  content.md  restructure-plan.md  rename-proposals.md
  wallpaper-library/   spec, architecture (the current file), report, operations, scene-renderer-diagnosis, import
  Reports/  design/  third-party/
```

### Where the plan departs from the starting layout, and why

1. **App shell out of `Design/`** [R]. `AppNavigation` and `SearchOverlay` depend on `AppPage` and `AppServices`; they are not design-system code.
2. **`Aesthetics/` becomes `Imagery/`, not part of Wallpaper** [R]. The usage is in section 2, problem 3. `WallpaperQuery` is a photo-search query despite its name; its only users are `PhotoSearch` and `Wallhaven`.
3. **`LibraryPages.swift` goes to `Features/Widgets/Studio/`** [R]. It's the widget options image picker.
4. **Core folder renames to pair with features: `Audio/` → `Mixer/`, `AI/` → `Screenshot/`** [R]. Every user of `Audio/` is in Mixer, `AppServices` or `MixerTests`. Every user of `AI/` is in Screenshot or its tests. Afterwards, all 12 `Features/` folders have a `Core` folder of the same name.
5. **`WidgetTheme*.swift` move to `AllSetCore/Themes/`** [R]. This separates concept C3 from C2.
6. **`Support/` split** [R]:
   - Storage: `StoreFile`, `DataArchive`, `FileDigest`
   - Security: `KeychainItem`, `AdminGate`, `ContainedPath`
   - Concurrency: `CommandRunner`, `LineReader`, `SharedRequests`, `RetryBackoff`
   - Performance: `PerformancePolicy`, `NeededTimer`, `CostCache`, `ImageCost`
   - Text: `Format`, plus `SearchMatch` from `Search/`
   - Display: `DisplayIdentity`, `ScreenCoverage`

   "Text" replaces "Formatting" because it holds matching too. "Performance" is new; its doc comments are all about keeping the app cheap. `RollingSeries` goes to `System/`, because only system sparklines use it. `DeepLink` stays at the `Support/` root, because no group fits it.
7. **`DeleteAPIKeychain` stays in Wallpaper** [R]. See section 2, problem 7.
8. **Seven test files stay at the test root** [R]. `TestEnvironment` is a shared helper, `LiveSystemTests` can't move (`#filePath`), and the 5 mixed files have no majority area. Placing those five by plurality would misfile most of their suites; splits are proposed instead.
9. **Wallpaper-library docs get a subfolder** [R]. All six are about the wallpaper library, and moving `architecture.md` there keeps its content and history while freeing the name for the app-wide map. The root `design/` folder joins `Documentation/design/` (the brief didn't mention it).
10. **Four file renames, each to the file's primary type** [R]:
    - `StudioThemeStyle` → `StudioAtmosphere`
    - `CinematicWidgets` → `GalleryPage` (its only type)
    - the app's `ScreenshotStudio` → `ScreenshotStudioView` (295 of 421 lines; this solves problem 6)
    - `HardeningTests` → `StoreFileTests` (170 of 181 lines)

### Widget kinds, grouped by what they do

Each widget's job comes from its doc comment [R]. Where there is none, it comes from the type name and body [I]. A file that does several things goes to the job that has the most lines. Splitting it is a content edit, so it's proposed in rename-proposals.

| File | What its widgets do | Lines per job | Folder |
|---|---|---|---|
| `ClockWidget` | clock faces [I] | Time 566 | **Time** |
| `LifestyleAndAestheticWidgets` ✱ | RetroWindow "the time in a 1984 window"; Enso "closes as the day goes by"; Magazine "today… a huge date" [R]; AirQuality "US AQI" [R] | Time ≈184, Weather ≈108 | **Time** |
| `CalendarWidget` | events and month grid [I] | Calendar 174 | **Calendar** |
| `FocusWidgets` ✱ | Todo (checklist), Focus (Pomodoro) [R]; Stopwatch [I] | Focus ≈400, Time ≈116 | **Focus** |
| `ProductivityWidgets` ✱ | Goals, Habits, Reading [R]; Date "today, big"; NextEvent "what's next" [R] | Focus ≈350, Calendar ≈147, Time 87 | **Focus** |
| `SystemWidgets` ✱ | System, Battery [I]; NowPlaying [I]; Note [I] | System ≈213, Music ≈162, Focus 44 | **System** |
| `SystemMetricWidget` | "one reading from the Mac" [R] | System 475 | **System** |
| `DarkWidgets` ✱ | Terminal "live stats as a shell session"; Dots "every day as a dot"; Neon "words… in glowing tubes" [R] | System ≈135, Time ≈116, Decor 50 | **System** |
| `WeatherWidget` | weather [I] | Weather 376 | **Weather** |
| `DaylightWidget` | "the sky as it is right now where you are" [R] | Weather 383 | **Weather** |
| `DeveloperWidgets` | GitHub, site/API status [R] | Developer 388 | **Developer** |
| `MusicWidgets` ✱ | Cassette, Visualizer [I]; Ticket "the show, the venue… days to go" [R]; VHS "a photo as home video" [R]; WordArt [I] | Music ≈439, Decor ≈177 | **Music** |
| `FootballWidgets` | jersey, player card, pitch, scoreboard, milestone [R/I] | Sports 996 | **Sports** |
| `AestheticWidgets` ✱ | Photo, Quote [I]; Ambient "what floats on top" of art [R]; Countdown [I] | Decor ≈470, Time 42 | **Decor** |
| `DecorWidgets` ✱ | Sticker "a big shape… on the desktop" [R]; Shortcuts "icons, each opening an app or a site" [R] | Decor ≈122, Focus ≈105 | **Decor** |
| `MysticWidgets` | spiral, charm, label, aura, tarot, zodiac, 8-ball, candle: decorative novelties [I] | Decor 1030 | **Decor** |
| `PolaroidsWidget` | "instant-film prints lying loose on the desktop" [R] | Decor 127 | **Decor** |
| `SceneWidgets` ✱ | LockScreen "a big clock over a photo" with subject cut-out [R]; Vinyl "a record that spins while music plays" [R]; Moon "tonight's moon" [R] | Decor ≈240, Music ≈214, Weather ≈178 | **Decor** |
| `CinematicWidgetFace` | alternative face for six kinds across groups (`supports(_:)`) [R] | — | `Kinds/` root |

The folders are the nine from the brief, with two name changes. "Clock" became **Time**, because it also holds date and day-progress widgets. "Decor/Scenes" became **Decor**, a single word. ✱ marks a file that does more than one job (10 of 19).

## 6. Phases, each small enough to build and test on its own

Each phase runs on branch `restructure/file-layout` and ends with:
- `swift build`, with 0 `warning:` lines;
- `swift test`, with 432 tests in 100 suites and 0 skipped;
- one commit.

If either check fails, the phase is fixed or reverted before the next one starts. Before P1: `.build/debug/AllSet -renderPages <scratch>/before`.

| Phase | What | Moves |
|---|---|---|
| P1 | App shell | 8 |
| P2 | Design merge | 16 |
| P3 | Debug harnesses | 3 |
| P4 | Studio split | 18 |
| P5 | App features | 49 |
| P6 | Widget kinds | 19 |
| P7 | Core feature folders | 23 |
| P8 | Core Support split | 19 |
| P9 | Tests mirror | 37 |
| P10 | Documentation merge | 36 |
| | **Total** | **228** |

**P11 (no moves): path updates.** Every row of section 3 marked "update in P11", the new `Documentation/architecture.md` (title, date, what each folder is for) and a `Documentation/README.md` index.

**After P11:**
- a clean `swift build` and `swift test`;
- `scripts/check-repo-hygiene.sh`;
- `git diff -M100% --summary main...HEAD -- Sources Tests`, which must show only renames;
- `-renderPages` compared with the before set (same file names and count);
- `grep -rn "Sources/" .github Makefile .vscode`;
- push `restructure/file-layout`, open a pull request and wait for CI to pass. **Do not merge it.**

## 7. The riskiest moves

| # | Move | Risk | Why, and the check |
|---|---|---|---|
| 1 | `AllSetCore/Aesthetics/ImageLibrary.swift` → `Imagery/` | **high** | Holds the `Bundle.main`/`Bundle.module` `ThemeArt` lookup. It's expected to be unaffected (the bundle is per target), but a resource lookup could change behaviour. Check: `ThemeLibraryTests`, plus the theme-card pages in `-renderPages`, must match. |
| 2 | `Widgets/WidgetRenderHarness.swift` → `Debug/` | med | It drives CI's `screenshots` job. Check: `-renderPages` writes the same files, and `render-report.txt` lists none missing. |
| 3 | `Widgets/PageCPUProbe.swift`, `Studio/Themes/CarouselProbe.swift` → `Debug/` | med | They drive CI's `probe` job, and `CarouselProbe` extends `PageCPUProbe`. Check: `-probe scroll\|pages\|galleryparts` runs and `check_probe_budgets.py` passes. |
| 4 | `docs/reference/*.png` → `Documentation/design/reference/` | med | `scripts/review-hero.sh` reads one of them. The script is updated in the same commit; then run `make review`, or check that the path exists. |
| 5 | Four file renames (`StudioThemeStyle`, `CinematicWidgets`, the app's `ScreenshotStudio`, `HardeningTests`) | med | Same content, new name. Git rename detection must show `R100`; P11 updates the doc paths that point at the old names. |
| — | *Not moved because of risk:* `LiveSystemTests.swift` (`#filePath`), `Sources/AllSetCore/Resources/ThemeArt`, `scripts/`, `Resources/`, `Documentation/third-party/`, `Documentation/HANDOFF.md` | — | Each is read by a path in code or a script (section 3). |

## 8. Decisions (answered 2026-10-15)

No questions are open. The plan above already reflected each answer, so none of them changed the move table or the file counts.

1. Widget folders follow **what the widgets do** (section 5), not the app's gallery categories.
2. The folder names are **`Time`** and **`Decor`**.
3. **`DeleteAPIKeychain` stays** in `AllSetCore/Wallpaper/`.
4. The six wallpaper-library docs move to **`Documentation/wallpaper-library/`**, and `Documentation/architecture.md` becomes the new app-wide map.
5. **Five mixed test files stay at the test root** until they're split: `LogicTests`, `NotesAndPDFTests`, `ThemesAndSearchTests`, `WidgetNetworkTests`, `WidgetTests`. So do `TestEnvironment` and `LiveSystemTests` (`#filePath`), for seven in all.
6. This revision of the plan is committed on `restructure/file-layout` (plan files only).
7. After P11, the branch is pushed and a pull request opened so CI runs. **The pull request is not merged.**

The moves start only with the Phase 2 prompt.

## Not in scope, noticed while reading

- `ThemeWidgetRails` (`ThemeWidgetGallery.swift`) has no reference outside its own file [R]. It may be dead code.
- `SendableImage` is declared in both targets (`LiveLayers.swift` and `AIImageEditors.swift`) [R]. See rename-proposals.
- `LidPlane/EffectDefaults.swift` declares `LidPlaneDefaults` [R]. The file name doesn't match, but it's not on the problem list.

## Appendix A: every proposed move

Generated from one move list, the same list Phase 2 will execute, so the table and the moves can't drift apart. A script checks it against `git ls-files`: every source exists, nothing moves twice, nothing crosses a target, and no target gets a duplicate file name.

Risk: **high** means the file contains a path or resource lookup. **med** means a renamed file, a CI-driving debug harness, or a file a script reads by path. **low** means a move that only changes the folder.

### P1 App shell

| Current path | New path | Reason | Risk |
|---|---|---|---|
| `Sources/AllSet/AllSetApp.swift` | `Sources/AllSet/App/AllSetApp.swift` | App entry, services and main window | low |
| `Sources/AllSet/AppDelegate.swift` | `Sources/AllSet/App/AppDelegate.swift` | App entry, services and main window | low |
| `Sources/AllSet/AppServices.swift` | `Sources/AllSet/App/AppServices.swift` | App entry, services and main window | low |
| `Sources/AllSet/AppServices+Themes.swift` | `Sources/AllSet/App/AppServices+Themes.swift` | App entry, services and main window | low |
| `Sources/AllSet/MainWindow.swift` | `Sources/AllSet/App/MainWindow.swift` | App entry, services and main window | low |
| `Sources/AllSet/MenuBar/MenuBarContentView.swift` | `Sources/AllSet/App/MenuBar/MenuBarContentView.swift` | App entry, services and main window | low |
| `Sources/AllSet/Design/AppNavigation.swift` | `Sources/AllSet/App/AppNavigation.swift` | Main window navigation: switches over AppPage, reads AppServices; app shell, not design system | low |
| `Sources/AllSet/Design/SearchOverlay.swift` | `Sources/AllSet/App/SearchOverlay.swift` | Cmd-K search and toasts of the main window; app shell | low |

### P2 Design merge

| Current path | New path | Reason | Risk |
|---|---|---|---|
| `Sources/AllSet/Design/DesignTokens.swift` | `Sources/AllSet/Design/Tokens/DesignTokens.swift` | Design tokens / colour constants | low |
| `Sources/AllSet/Components/Theme.swift` | `Sources/AllSet/Design/Tokens/Theme.swift` | Design tokens / colour constants | low |
| `Sources/AllSet/Components/Motion.swift` | `Sources/AllSet/Design/Motion/Motion.swift` | Shared motion (Motion vocabulary, Core Animation movers) | low |
| `Sources/AllSet/Components/DriftingImage.swift` | `Sources/AllSet/Design/Motion/DriftingImage.swift` | Shared motion (Motion vocabulary, Core Animation movers) | low |
| `Sources/AllSet/Components/LiveLayers.swift` | `Sources/AllSet/Design/Motion/LiveLayers.swift` | Shared motion (Motion vocabulary, Core Animation movers) | low |
| `Sources/AllSet/Components/Components.swift` | `Sources/AllSet/Design/Components/Components.swift` | Shared UI components | low |
| `Sources/AllSet/Components/KeyboardActivatable.swift` | `Sources/AllSet/Design/Components/KeyboardActivatable.swift` | Shared UI components | low |
| `Sources/AllSet/Components/LayerGauges.swift` | `Sources/AllSet/Design/Components/LayerGauges.swift` | Shared UI components | low |
| `Sources/AllSet/Design/DesignComponents.swift` | `Sources/AllSet/Design/Components/DesignComponents.swift` | Shared UI components | low |
| `Sources/AllSet/Design/CinemaDesign.swift` | `Sources/AllSet/Design/Components/CinemaDesign.swift` | Shared UI components | low |
| `Sources/AllSet/Design/WindowBackdrop.swift` | `Sources/AllSet/Design/Backdrop/WindowBackdrop.swift` | Window/page backdrops | low |
| `Sources/AllSet/Studio/StudioThemeStyle.swift` | `Sources/AllSet/Design/Backdrop/StudioAtmosphere.swift` | File rename: no type is named StudioThemeStyle; StudioAtmosphere is the primary type. Shared backdrop + controls of the Desktop pages (MainWindow, Wallpaper, Widgets gallery) | med |
| `Sources/AllSet/Widgets/Design/WidgetStyle.swift` | `Sources/AllSet/Design/Widget/WidgetStyle.swift` | Widget design system (style resolution and widget components) | low |
| `Sources/AllSet/Widgets/Design/WidgetComponents.swift` | `Sources/AllSet/Design/Widget/WidgetComponents.swift` | Widget design system (style resolution and widget components) | low |
| `Sources/AllSet/Widgets/Design/DesignSurface.swift` | `Sources/AllSet/Design/Widget/DesignSurface.swift` | Widget design system (style resolution and widget components) | low |
| `Sources/AllSet/Widgets/Design/WidgetWord.swift` | `Sources/AllSet/Design/Widget/WidgetWord.swift` | Widget design system (style resolution and widget components) | low |

### P3 Debug harnesses

| Current path | New path | Reason | Risk |
|---|---|---|---|
| `Sources/AllSet/Widgets/PageCPUProbe.swift` | `Sources/AllSet/Debug/PageCPUProbe.swift` | DEBUG-only harness (whole file #if DEBUG), used by AppDelegate's -renderPages/-probe | med |
| `Sources/AllSet/Widgets/WidgetRenderHarness.swift` | `Sources/AllSet/Debug/WidgetRenderHarness.swift` | DEBUG-only harness (whole file #if DEBUG), used by AppDelegate's -renderPages/-probe | med |
| `Sources/AllSet/Studio/Themes/CarouselProbe.swift` | `Sources/AllSet/Debug/CarouselProbe.swift` | DEBUG-only harness (whole file #if DEBUG), used by AppDelegate's -renderPages/-probe | med |

### P4 Studio split

| Current path | New path | Reason | Risk |
|---|---|---|---|
| `Sources/AllSet/Studio/ThemesPage.swift` | `Sources/AllSet/Features/Themes/ThemesPage.swift` | Themes page UI | low |
| `Sources/AllSet/Studio/ThemePreviews.swift` | `Sources/AllSet/Features/Themes/ThemePreviews.swift` | Themes page UI | low |
| `Sources/AllSet/Studio/ThemeWidgetGallery.swift` | `Sources/AllSet/Features/Themes/ThemeWidgetGallery.swift` | Themes page UI | low |
| `Sources/AllSet/Studio/FavoritesPage.swift` | `Sources/AllSet/Features/Themes/FavoritesPage.swift` | Themes page UI | low |
| `Sources/AllSet/Studio/Themes/CardHalo.swift` | `Sources/AllSet/Features/Themes/CardHalo.swift` | Themes page UI | low |
| `Sources/AllSet/Studio/Themes/CategoryRail.swift` | `Sources/AllSet/Features/Themes/CategoryRail.swift` | Themes page UI | low |
| `Sources/AllSet/Studio/Themes/HeroCarousel.swift` | `Sources/AllSet/Features/Themes/HeroCarousel.swift` | Themes page UI | low |
| `Sources/AllSet/Studio/Themes/ThemeAtmosphere.swift` | `Sources/AllSet/Features/Themes/ThemeAtmosphere.swift` | Themes page UI | low |
| `Sources/AllSet/Studio/Themes/ThemePreviewCard.swift` | `Sources/AllSet/Features/Themes/ThemePreviewCard.swift` | Themes page UI | low |
| `Sources/AllSet/Studio/Themes/ThemeRail.swift` | `Sources/AllSet/Features/Themes/ThemeRail.swift` | Themes page UI | low |
| `Sources/AllSet/Studio/Themes/ThemesFilterBar.swift` | `Sources/AllSet/Features/Themes/ThemesFilterBar.swift` | Themes page UI | low |
| `Sources/AllSet/Studio/Themes/ThemesHero.swift` | `Sources/AllSet/Features/Themes/ThemesHero.swift` | Themes page UI | low |
| `Sources/AllSet/Studio/CinematicCatalog.swift` | `Sources/AllSet/Features/Widgets/Studio/CinematicCatalog.swift` | Widget gallery / editing UI (LibraryPages is the widget options image picker) | low |
| `Sources/AllSet/Studio/LibraryWidgetPreview.swift` | `Sources/AllSet/Features/Widgets/Studio/LibraryWidgetPreview.swift` | Widget gallery / editing UI (LibraryPages is the widget options image picker) | low |
| `Sources/AllSet/Studio/WidgetOptionsEditor.swift` | `Sources/AllSet/Features/Widgets/Studio/WidgetOptionsEditor.swift` | Widget gallery / editing UI (LibraryPages is the widget options image picker) | low |
| `Sources/AllSet/Studio/WidgetStudio.swift` | `Sources/AllSet/Features/Widgets/Studio/WidgetStudio.swift` | Widget gallery / editing UI (LibraryPages is the widget options image picker) | low |
| `Sources/AllSet/Studio/LibraryPages.swift` | `Sources/AllSet/Features/Widgets/Studio/LibraryPages.swift` | Widget gallery / editing UI (LibraryPages is the widget options image picker) | low |
| `Sources/AllSet/Studio/CinematicWidgets.swift` | `Sources/AllSet/Features/Widgets/Studio/GalleryPage.swift` | File rename: GalleryPage is the only type. It is the Widgets gallery page | med |

### P5 App features

| Current path | New path | Reason | Risk |
|---|---|---|---|
| `Sources/AllSet/Wallpaper/DesktopCoverage.swift` | `Sources/AllSet/Features/Wallpaper/DesktopCoverage.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Wallpaper/WallpaperAtmosphere.swift` | `Sources/AllSet/Features/Wallpaper/WallpaperAtmosphere.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Wallpaper/WallpaperController.swift` | `Sources/AllSet/Features/Wallpaper/WallpaperController.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Wallpaper/WallpaperPages.swift` | `Sources/AllSet/Features/Wallpaper/WallpaperPages.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Clipboard/ClipboardMonitor.swift` | `Sources/AllSet/Features/Clipboard/ClipboardMonitor.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Clipboard/ClipboardPages.swift` | `Sources/AllSet/Features/Clipboard/ClipboardPages.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Clipboard/ClipboardPicker.swift` | `Sources/AllSet/Features/Clipboard/ClipboardPicker.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Knock/KnockActionRunner.swift` | `Sources/AllSet/Features/Knock/KnockActionRunner.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Knock/KnockController.swift` | `Sources/AllSet/Features/Knock/KnockController.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Knock/KnockPages.swift` | `Sources/AllSet/Features/Knock/KnockPages.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/LidPlane/LidPlaneCapture.swift` | `Sources/AllSet/Features/LidPlane/LidPlaneCapture.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/LidPlane/LidPlaneController.swift` | `Sources/AllSet/Features/LidPlane/LidPlaneController.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/LidPlane/LidPlaneDisplay.swift` | `Sources/AllSet/Features/LidPlane/LidPlaneDisplay.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/LidPlane/LidPlanePage.swift` | `Sources/AllSet/Features/LidPlane/LidPlanePage.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/LidPlane/LidPlaneRenderChecks.swift` | `Sources/AllSet/Features/LidPlane/LidPlaneRenderChecks.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/LidPlane/LidPlaneRenderer.swift` | `Sources/AllSet/Features/LidPlane/LidPlaneRenderer.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Mixer/MixerController.swift` | `Sources/AllSet/Features/Mixer/MixerController.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Mixer/MixerViews.swift` | `Sources/AllSet/Features/Mixer/MixerViews.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notch/CollapsedActivityView.swift` | `Sources/AllSet/Features/Notch/CollapsedActivityView.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notch/ExpandedPanel.swift` | `Sources/AllSet/Features/Notch/ExpandedPanel.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notch/HomeTab.swift` | `Sources/AllSet/Features/Notch/HomeTab.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notch/IslandPages.swift` | `Sources/AllSet/Features/Notch/IslandPages.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notch/IslandView.swift` | `Sources/AllSet/Features/Notch/IslandView.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notch/MemoryViews.swift` | `Sources/AllSet/Features/Notch/MemoryViews.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notch/NotchAnimation.swift` | `Sources/AllSet/Features/Notch/NotchAnimation.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notch/NotchController.swift` | `Sources/AllSet/Features/Notch/NotchController.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notch/NotchPanel.swift` | `Sources/AllSet/Features/Notch/NotchPanel.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notch/NotchRootView.swift` | `Sources/AllSet/Features/Notch/NotchRootView.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notch/NotchShape.swift` | `Sources/AllSet/Features/Notch/NotchShape.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notch/NotchViewModel.swift` | `Sources/AllSet/Features/Notch/NotchViewModel.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notch/SystemTab.swift` | `Sources/AllSet/Features/Notch/SystemTab.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notch/TrayTab.swift` | `Sources/AllSet/Features/Notch/TrayTab.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Notes/NotesViews.swift` | `Sources/AllSet/Features/Notes/NotesViews.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Settings/DataAndPrivacy.swift` | `Sources/AllSet/Features/Settings/DataAndPrivacy.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Settings/LaunchAtLogin.swift` | `Sources/AllSet/Features/Settings/LaunchAtLogin.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Settings/SettingsView.swift` | `Sources/AllSet/Features/Settings/SettingsView.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Settings/WidgetSettings.swift` | `Sources/AllSet/Features/Settings/WidgetSettings.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Workspace/Accessibility.swift` | `Sources/AllSet/Features/Workspace/Accessibility.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Workspace/WindowManager.swift` | `Sources/AllSet/Features/Workspace/WindowManager.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Workspace/WorkspaceController.swift` | `Sources/AllSet/Features/Workspace/WorkspaceController.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Workspace/WorkspacePages.swift` | `Sources/AllSet/Features/Workspace/WorkspacePages.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Screenshot/ScreenshotShortcutController.swift` | `Sources/AllSet/Features/Screenshot/ScreenshotShortcutController.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Widgets/ArtShader.swift` | `Sources/AllSet/Features/Widgets/ArtShader.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Widgets/ArtView.swift` | `Sources/AllSet/Features/Widgets/ArtView.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Widgets/Backgrounds.swift` | `Sources/AllSet/Features/Widgets/Backgrounds.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Widgets/DesktopWidgetController.swift` | `Sources/AllSet/Features/Widgets/DesktopWidgetController.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Widgets/WidgetGridOverlay.swift` | `Sources/AllSet/Features/Widgets/WidgetGridOverlay.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Widgets/WidgetHostView.swift` | `Sources/AllSet/Features/Widgets/WidgetHostView.swift` | Feature UI into Features/<name> | low |
| `Sources/AllSet/Widgets/WidgetWindow.swift` | `Sources/AllSet/Features/Widgets/WidgetWindow.swift` | Feature UI into Features/<name> | low |

### P6 Widget kinds

| Current path | New path | Reason | Risk |
|---|---|---|---|
| `Sources/AllSet/Widgets/Kinds/ClockWidget.swift` | `Sources/AllSet/Features/Widgets/Kinds/Time/ClockWidget.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/LifestyleAndAestheticWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Time/LifestyleAndAestheticWidgets.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/CalendarWidget.swift` | `Sources/AllSet/Features/Widgets/Kinds/Calendar/CalendarWidget.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/FocusWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Focus/FocusWidgets.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/ProductivityWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Focus/ProductivityWidgets.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/SystemWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/System/SystemWidgets.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/SystemMetricWidget.swift` | `Sources/AllSet/Features/Widgets/Kinds/System/SystemMetricWidget.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/DarkWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/System/DarkWidgets.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/WeatherWidget.swift` | `Sources/AllSet/Features/Widgets/Kinds/Weather/WeatherWidget.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/DaylightWidget.swift` | `Sources/AllSet/Features/Widgets/Kinds/Weather/DaylightWidget.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/DeveloperWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Developer/DeveloperWidgets.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/MusicWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Music/MusicWidgets.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/FootballWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Sports/FootballWidgets.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/AestheticWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Decor/AestheticWidgets.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/DecorWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Decor/DecorWidgets.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/MysticWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Decor/MysticWidgets.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/PolaroidsWidget.swift` | `Sources/AllSet/Features/Widgets/Kinds/Decor/PolaroidsWidget.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/SceneWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Decor/SceneWidgets.swift` | Grouped by what its widgets do (see Widget kinds table) | low |
| `Sources/AllSet/Widgets/Kinds/CinematicWidgetFace.swift` | `Sources/AllSet/Features/Widgets/Kinds/CinematicWidgetFace.swift` | Alternate face for six kinds across groups; stays at Kinds root | low |

### P7 Core feature folders

| Current path | New path | Reason | Risk |
|---|---|---|---|
| `Sources/AllSetCore/Aesthetics/Art.swift` | `Sources/AllSetCore/Imagery/Art.swift` | Shared imagery layer (used by widgets, themes and wallpaper), not wallpaper-only | low |
| `Sources/AllSetCore/Aesthetics/CuratedBackgrounds.swift` | `Sources/AllSetCore/Imagery/CuratedBackgrounds.swift` | Shared imagery layer (used by widgets, themes and wallpaper), not wallpaper-only | low |
| `Sources/AllSetCore/Aesthetics/ImageLibrary.swift` | `Sources/AllSetCore/Imagery/ImageLibrary.swift` | Shared imagery layer (used by widgets, themes and wallpaper), not wallpaper-only | high |
| `Sources/AllSetCore/Aesthetics/LicensedPhotos.swift` | `Sources/AllSetCore/Imagery/LicensedPhotos.swift` | Shared imagery layer (used by widgets, themes and wallpaper), not wallpaper-only | low |
| `Sources/AllSetCore/Aesthetics/PhotoSearch.swift` | `Sources/AllSetCore/Imagery/PhotoSearch.swift` | Shared imagery layer (used by widgets, themes and wallpaper), not wallpaper-only | low |
| `Sources/AllSetCore/Aesthetics/Wallhaven.swift` | `Sources/AllSetCore/Imagery/Wallhaven.swift` | Shared imagery layer (used by widgets, themes and wallpaper), not wallpaper-only | low |
| `Sources/AllSetCore/Aesthetics/WallpaperColor.swift` | `Sources/AllSetCore/Imagery/WallpaperColor.swift` | Shared imagery layer (used by widgets, themes and wallpaper), not wallpaper-only | low |
| `Sources/AllSetCore/Search/AestheticSearch.swift` | `Sources/AllSetCore/Imagery/AestheticSearch.swift` | Shared imagery layer (used by widgets, themes and wallpaper), not wallpaper-only | low |
| `Sources/AllSetCore/Search/WallpaperQuery.swift` | `Sources/AllSetCore/Imagery/WallpaperQuery.swift` | Shared imagery layer (used by widgets, themes and wallpaper), not wallpaper-only | low |
| `Sources/AllSetCore/Widgets/WidgetTheme.swift` | `Sources/AllSetCore/Themes/WidgetTheme.swift` | WidgetTheme is a whole desktop look wrapped by ThemeSet.Look.setup and ThemeLibrary | low |
| `Sources/AllSetCore/Widgets/WidgetTheme+Cinematic.swift` | `Sources/AllSetCore/Themes/WidgetTheme+Cinematic.swift` | WidgetTheme is a whole desktop look wrapped by ThemeSet.Look.setup and ThemeLibrary | low |
| `Sources/AllSetCore/Widgets/WidgetTheme+Colour.swift` | `Sources/AllSetCore/Themes/WidgetTheme+Colour.swift` | WidgetTheme is a whole desktop look wrapped by ThemeSet.Look.setup and ThemeLibrary | low |
| `Sources/AllSetCore/Widgets/WidgetTheme+Fandom.swift` | `Sources/AllSetCore/Themes/WidgetTheme+Fandom.swift` | WidgetTheme is a whole desktop look wrapped by ThemeSet.Look.setup and ThemeLibrary | low |
| `Sources/AllSetCore/Widgets/WidgetTheme+Moodboards.swift` | `Sources/AllSetCore/Themes/WidgetTheme+Moodboards.swift` | WidgetTheme is a whole desktop look wrapped by ThemeSet.Look.setup and ThemeLibrary | low |
| `Sources/AllSetCore/Audio/AppAudioTap.swift` | `Sources/AllSetCore/Mixer/AppAudioTap.swift` | Only users are the Mixer feature (+AppServices, MixerTests); pairs with Features/Mixer | low |
| `Sources/AllSetCore/Audio/AppVolumeStore.swift` | `Sources/AllSetCore/Mixer/AppVolumeStore.swift` | Only users are the Mixer feature (+AppServices, MixerTests); pairs with Features/Mixer | low |
| `Sources/AllSetCore/Audio/AudioCapturePermission.swift` | `Sources/AllSetCore/Mixer/AudioCapturePermission.swift` | Only users are the Mixer feature (+AppServices, MixerTests); pairs with Features/Mixer | low |
| `Sources/AllSetCore/Audio/AudioProcesses.swift` | `Sources/AllSetCore/Mixer/AudioProcesses.swift` | Only users are the Mixer feature (+AppServices, MixerTests); pairs with Features/Mixer | low |
| `Sources/AllSetCore/Audio/VolumeMonitor.swift` | `Sources/AllSetCore/Mixer/VolumeMonitor.swift` | Only users are the Mixer feature (+AppServices, MixerTests); pairs with Features/Mixer | low |
| `Sources/AllSet/Screenshot/ScreenshotStudio.swift` | `Sources/AllSet/Features/Screenshot/ScreenshotStudioView.swift` | File rename to its primary type ScreenshotStudioView (295/421 lines); ends the same file name in both targets (problem 6) | med |
| `Sources/AllSetCore/AI/ScreenshotStudio.swift` | `Sources/AllSetCore/Screenshot/ScreenshotStudio.swift` | Only users are the Screenshot feature and its tests; pairs with Features/Screenshot | low |
| `Sources/AllSetCore/AI/ScreenshotEdit.swift` | `Sources/AllSetCore/Screenshot/ScreenshotEdit.swift` | Only users are the Screenshot feature and its tests; pairs with Features/Screenshot | low |
| `Sources/AllSetCore/AI/AIImageEditors.swift` | `Sources/AllSetCore/Screenshot/AIImageEditors.swift` | Only users are the Screenshot feature and its tests; pairs with Features/Screenshot | low |

### P8 Core Support split

| Current path | New path | Reason | Risk |
|---|---|---|---|
| `Sources/AllSetCore/Support/StoreFile.swift` | `Sources/AllSetCore/Support/Storage/StoreFile.swift` | Support grouped by purpose: Storage | low |
| `Sources/AllSetCore/Support/DataArchive.swift` | `Sources/AllSetCore/Support/Storage/DataArchive.swift` | Support grouped by purpose: Storage | low |
| `Sources/AllSetCore/Support/FileDigest.swift` | `Sources/AllSetCore/Support/Storage/FileDigest.swift` | Support grouped by purpose: Storage | low |
| `Sources/AllSetCore/Support/KeychainItem.swift` | `Sources/AllSetCore/Support/Security/KeychainItem.swift` | Support grouped by purpose: Security | low |
| `Sources/AllSetCore/Support/AdminGate.swift` | `Sources/AllSetCore/Support/Security/AdminGate.swift` | Support grouped by purpose: Security | low |
| `Sources/AllSetCore/Support/ContainedPath.swift` | `Sources/AllSetCore/Support/Security/ContainedPath.swift` | Support grouped by purpose: Security | low |
| `Sources/AllSetCore/Support/CommandRunner.swift` | `Sources/AllSetCore/Support/Concurrency/CommandRunner.swift` | Support grouped by purpose: Concurrency | low |
| `Sources/AllSetCore/Support/LineReader.swift` | `Sources/AllSetCore/Support/Concurrency/LineReader.swift` | Support grouped by purpose: Concurrency | low |
| `Sources/AllSetCore/Support/SharedRequests.swift` | `Sources/AllSetCore/Support/Concurrency/SharedRequests.swift` | Support grouped by purpose: Concurrency | low |
| `Sources/AllSetCore/Support/RetryBackoff.swift` | `Sources/AllSetCore/Support/Concurrency/RetryBackoff.swift` | Support grouped by purpose: Concurrency | low |
| `Sources/AllSetCore/Support/PerformancePolicy.swift` | `Sources/AllSetCore/Support/Performance/PerformancePolicy.swift` | Support grouped by purpose: Performance | low |
| `Sources/AllSetCore/Support/NeededTimer.swift` | `Sources/AllSetCore/Support/Performance/NeededTimer.swift` | Support grouped by purpose: Performance | low |
| `Sources/AllSetCore/Support/CostCache.swift` | `Sources/AllSetCore/Support/Performance/CostCache.swift` | Support grouped by purpose: Performance | low |
| `Sources/AllSetCore/Support/ImageCost.swift` | `Sources/AllSetCore/Support/Performance/ImageCost.swift` | Support grouped by purpose: Performance | low |
| `Sources/AllSetCore/Support/Format.swift` | `Sources/AllSetCore/Support/Text/Format.swift` | Support grouped by purpose: Text | low |
| `Sources/AllSetCore/Support/DisplayIdentity.swift` | `Sources/AllSetCore/Support/Display/DisplayIdentity.swift` | Support grouped by purpose: Display | low |
| `Sources/AllSetCore/Support/ScreenCoverage.swift` | `Sources/AllSetCore/Support/Display/ScreenCoverage.swift` | Support grouped by purpose: Display | low |
| `Sources/AllSetCore/Search/SearchMatch.swift` | `Sources/AllSetCore/Support/Text/SearchMatch.swift` | Text matching used by nine features; Search/ is otherwise emptied | low |
| `Sources/AllSetCore/Support/RollingSeries.swift` | `Sources/AllSetCore/System/RollingSeries.swift` | Only used for system metric sparklines (SystemMonitor, notch) | low |

### P9 Tests mirror

| Current path | New path | Reason | Risk |
|---|---|---|---|
| `Tests/AllSetCoreTests/ClipboardTests.swift` | `Tests/AllSetCoreTests/Clipboard/ClipboardTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/ImageImportTests.swift` | `Tests/AllSetCoreTests/Imagery/ImageImportTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/WallpaperSearchTests.swift` | `Tests/AllSetCoreTests/Imagery/WallpaperSearchTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/KnockTests.swift` | `Tests/AllSetCoreTests/Knock/KnockTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/LidPlaneTests.swift` | `Tests/AllSetCoreTests/LidPlane/LidPlaneTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/MixerTests.swift` | `Tests/AllSetCoreTests/Mixer/MixerTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/GainBoxTests.swift` | `Tests/AllSetCoreTests/Mixer/GainBoxTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/ScreenshotAITests.swift` | `Tests/AllSetCoreTests/Screenshot/ScreenshotAITests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/ScreenshotShortcutTests.swift` | `Tests/AllSetCoreTests/Screenshot/ScreenshotShortcutTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/ScreenshotStudioTests.swift` | `Tests/AllSetCoreTests/Screenshot/ScreenshotStudioTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/CommandRunnerTests.swift` | `Tests/AllSetCoreTests/Support/CommandRunnerTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/ContainedPathTests.swift` | `Tests/AllSetCoreTests/Support/ContainedPathTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/CostCacheTests.swift` | `Tests/AllSetCoreTests/Support/CostCacheTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/DataArchiveTests.swift` | `Tests/AllSetCoreTests/Support/DataArchiveTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/DisplayIdentityTests.swift` | `Tests/AllSetCoreTests/Support/DisplayIdentityTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/KeychainItemTests.swift` | `Tests/AllSetCoreTests/Support/KeychainItemTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/NeededTimerTests.swift` | `Tests/AllSetCoreTests/Support/NeededTimerTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/PerformancePolicyTests.swift` | `Tests/AllSetCoreTests/Support/PerformancePolicyTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/SearchMatchTests.swift` | `Tests/AllSetCoreTests/Support/SearchMatchTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/BatteryHealthTests.swift` | `Tests/AllSetCoreTests/System/BatteryHealthTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/BatteryTests.swift` | `Tests/AllSetCoreTests/System/BatteryTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/DesktopJournalTests.swift` | `Tests/AllSetCoreTests/Themes/DesktopJournalTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/DesktopSnapshotTests.swift` | `Tests/AllSetCoreTests/Themes/DesktopSnapshotTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/ThemeCarouselLayoutTests.swift` | `Tests/AllSetCoreTests/Themes/ThemeCarouselLayoutTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/ThemeLibraryTests.swift` | `Tests/AllSetCoreTests/Themes/ThemeLibraryTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/ThemeWidgetCatalogTests.swift` | `Tests/AllSetCoreTests/Themes/ThemeWidgetCatalogTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/FandomTests.swift` | `Tests/AllSetCoreTests/Themes/FandomTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/WallpaperLibraryTests.swift` | `Tests/AllSetCoreTests/Wallpaper/WallpaperLibraryTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/FocusTimerCoordinatorTests.swift` | `Tests/AllSetCoreTests/Widgets/FocusTimerCoordinatorTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/MysticTests.swift` | `Tests/AllSetCoreTests/Widgets/MysticTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/StudioDiscoveryTests.swift` | `Tests/AllSetCoreTests/Widgets/StudioDiscoveryTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/WidgetGridTests.swift` | `Tests/AllSetCoreTests/Widgets/WidgetGridTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/WidgetResizeTests.swift` | `Tests/AllSetCoreTests/Widgets/WidgetResizeTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/WidgetPlatformTests.swift` | `Tests/AllSetCoreTests/Widgets/WidgetPlatformTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/AestheticsV2Tests.swift` | `Tests/AllSetCoreTests/Widgets/AestheticsV2Tests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/WorkspaceTests.swift` | `Tests/AllSetCoreTests/Workspace/WorkspaceTests.swift` | Mirrors the Core folder of what it tests (majority of lines) | low |
| `Tests/AllSetCoreTests/HardeningTests.swift` | `Tests/AllSetCoreTests/Support/StoreFileTests.swift` | File rename: StoreFileTests is 170/181 lines (plus 7-line PhotoURLTests) | med |

### P10 Documentation merge

| Current path | New path | Reason | Risk |
|---|---|---|---|
| `docs/UI-Spec.md` | `Documentation/UI-Spec.md` | One documentation tree | low |
| `docs/perf-audit.md` | `Documentation/perf-audit.md` | One documentation tree | low |
| `docs/wallpaper-import.md` | `Documentation/wallpaper-library/import.md` | Wallpaper library doc; grouped so architecture.md can become the app map | low |
| `Documentation/spec.md` | `Documentation/wallpaper-library/spec.md` | Wallpaper library doc; grouped so architecture.md can become the app map | low |
| `Documentation/architecture.md` | `Documentation/wallpaper-library/architecture.md` | Wallpaper library doc; grouped so architecture.md can become the app map | low |
| `Documentation/report.md` | `Documentation/wallpaper-library/report.md` | Wallpaper library doc; grouped so architecture.md can become the app map | low |
| `Documentation/operations.md` | `Documentation/wallpaper-library/operations.md` | Wallpaper library doc; grouped so architecture.md can become the app map | low |
| `Documentation/scene-renderer-diagnosis.md` | `Documentation/wallpaper-library/scene-renderer-diagnosis.md` | Wallpaper library doc; grouped so architecture.md can become the app map | low |
| `Documentation/audit-2026-09-29.md` | `Documentation/Reports/2026-09-29-audit.md` | One documentation tree | low |
| `rules_frontend.md` | `Documentation/frontend-rules.md` | One documentation tree | low |
| `CONTENT.md` | `Documentation/content.md` | One documentation tree | low |
| `docs/reference/concept2-reference.png` | `Documentation/design/reference/concept2-reference.png` | Design reference image; review-hero.sh path updated in the same commit | med |
| `docs/reference/themes-scroll-target.png` | `Documentation/design/reference/themes-scroll-target.png` | Design reference image; review-hero.sh path updated in the same commit | med |
| `design/themes-concepts/2026-10-05-cinematic-reference/aurora-asset-prompt.json` | `Documentation/design/themes-concepts/2026-10-05-cinematic-reference/aurora-asset-prompt.json` | Root design/ folder joins the one documentation tree | low |
| `design/themes-concepts/2026-10-05-cinematic-reference/prompt.json` | `Documentation/design/themes-concepts/2026-10-05-cinematic-reference/prompt.json` | Root design/ folder joins the one documentation tree | low |
| `design/themes-concepts/2026-10-05-cinematic-reference/themes-preview.png` | `Documentation/design/themes-concepts/2026-10-05-cinematic-reference/themes-preview.png` | Root design/ folder joins the one documentation tree | low |
| `design/themes-concepts/2026-10-05-original/01-editorial-studio.png` | `Documentation/design/themes-concepts/2026-10-05-original/01-editorial-studio.png` | Root design/ folder joins the one documentation tree | low |
| `design/themes-concepts/2026-10-05-original/02-chromatic-lab.png` | `Documentation/design/themes-concepts/2026-10-05-original/02-chromatic-lab.png` | Root design/ folder joins the one documentation tree | low |
| `design/themes-concepts/2026-10-05-original/03-soft-spatial.png` | `Documentation/design/themes-concepts/2026-10-05-original/03-soft-spatial.png` | Root design/ folder joins the one documentation tree | low |
| `design/themes-concepts/2026-10-05-original/prompts.json` | `Documentation/design/themes-concepts/2026-10-05-original/prompts.json` | Root design/ folder joins the one documentation tree | low |
| `design/themes-concepts/2026-10-05/01-cinematic-carousel.png` | `Documentation/design/themes-concepts/2026-10-05/01-cinematic-carousel.png` | Root design/ folder joins the one documentation tree | low |
| `design/themes-concepts/2026-10-05/02-gallery-atelier.png` | `Documentation/design/themes-concepts/2026-10-05/02-gallery-atelier.png` | Root design/ folder joins the one documentation tree | low |
| `design/themes-concepts/2026-10-05/03-immersive-desktop.png` | `Documentation/design/themes-concepts/2026-10-05/03-immersive-desktop.png` | Root design/ folder joins the one documentation tree | low |
| `design/themes-concepts/2026-10-05/prompts.json` | `Documentation/design/themes-concepts/2026-10-05/prompts.json` | Root design/ folder joins the one documentation tree | low |
| `design/wallpaper-concepts/2026-10-05-v2/01-cinematic-library.png` | `Documentation/design/wallpaper-concepts/2026-10-05-v2/01-cinematic-library.png` | Root design/ folder joins the one documentation tree | low |
| `design/wallpaper-concepts/2026-10-05-v2/02-preview-studio.png` | `Documentation/design/wallpaper-concepts/2026-10-05-v2/02-preview-studio.png` | Root design/ folder joins the one documentation tree | low |
| `design/wallpaper-concepts/2026-10-05-v2/03-immersive-cinema.png` | `Documentation/design/wallpaper-concepts/2026-10-05-v2/03-immersive-cinema.png` | Root design/ folder joins the one documentation tree | low |
| `design/wallpaper-concepts/2026-10-05-v2/prompts.json` | `Documentation/design/wallpaper-concepts/2026-10-05-v2/prompts.json` | Root design/ folder joins the one documentation tree | low |
| `design/wallpaper-concepts/2026-10-05/01-cinematic-discovery.png` | `Documentation/design/wallpaper-concepts/2026-10-05/01-cinematic-discovery.png` | Root design/ folder joins the one documentation tree | low |
| `design/wallpaper-concepts/2026-10-05/02-gallery-inspector.png` | `Documentation/design/wallpaper-concepts/2026-10-05/02-gallery-inspector.png` | Root design/ folder joins the one documentation tree | low |
| `design/wallpaper-concepts/2026-10-05/03-immersive-theater.png` | `Documentation/design/wallpaper-concepts/2026-10-05/03-immersive-theater.png` | Root design/ folder joins the one documentation tree | low |
| `design/wallpaper-concepts/2026-10-05/prompts.json` | `Documentation/design/wallpaper-concepts/2026-10-05/prompts.json` | Root design/ folder joins the one documentation tree | low |
| `design/wallpaper-concepts/SELECTED.md` | `Documentation/design/wallpaper-concepts/SELECTED.md` | Root design/ folder joins the one documentation tree | low |
| `design/widgets-concepts/2026-10-05/01-widget-library.png` | `Documentation/design/widgets-concepts/2026-10-05/01-widget-library.png` | Root design/ folder joins the one documentation tree | low |
| `design/widgets-concepts/2026-10-05/asset-manifest.json` | `Documentation/design/widgets-concepts/2026-10-05/asset-manifest.json` | Root design/ folder joins the one documentation tree | med |
| `design/widgets-concepts/SELECTED.md` | `Documentation/design/widgets-concepts/SELECTED.md` | Root design/ folder joins the one documentation tree | low |

## Appendix B: count check against `git ls-files`

Each folder's tracked files equal moved plus staying; the generator asserts that the moved total equals the number of rows in Appendix A. Folders outside this list (`.github`, `.vscode`, `Resources`, `scripts`) don't move.

| Folder | Tracked files | Moved | Stay |
|---|---|---|---|
| `(repo root)` | 6 | 2 | 4 |
| `Documentation` | 9 | 6 | 3 |
| `Documentation/Reports` | 30 | 0 | 30 |
| `Documentation/third-party` | 2 | 0 | 2 |
| `Sources/AllSet` | 5 | 5 | 0 |
| `Sources/AllSet/Clipboard` | 3 | 3 | 0 |
| `Sources/AllSet/Components` | 7 | 7 | 0 |
| `Sources/AllSet/Design` | 6 | 6 | 0 |
| `Sources/AllSet/Knock` | 3 | 3 | 0 |
| `Sources/AllSet/LidPlane` | 6 | 6 | 0 |
| `Sources/AllSet/MenuBar` | 1 | 1 | 0 |
| `Sources/AllSet/Mixer` | 2 | 2 | 0 |
| `Sources/AllSet/Notch` | 14 | 14 | 0 |
| `Sources/AllSet/Notes` | 1 | 1 | 0 |
| `Sources/AllSet/Screenshot` | 2 | 2 | 0 |
| `Sources/AllSet/Settings` | 4 | 4 | 0 |
| `Sources/AllSet/Studio` | 11 | 11 | 0 |
| `Sources/AllSet/Studio/Themes` | 9 | 9 | 0 |
| `Sources/AllSet/Wallpaper` | 4 | 4 | 0 |
| `Sources/AllSet/Widgets` | 9 | 9 | 0 |
| `Sources/AllSet/Widgets/Design` | 4 | 4 | 0 |
| `Sources/AllSet/Widgets/Kinds` | 19 | 19 | 0 |
| `Sources/AllSet/Workspace` | 4 | 4 | 0 |
| `Sources/AllSetCore/AI` | 3 | 3 | 0 |
| `Sources/AllSetCore/Aesthetics` | 7 | 7 | 0 |
| `Sources/AllSetCore/Audio` | 5 | 5 | 0 |
| `Sources/AllSetCore/Calendar` | 2 | 0 | 2 |
| `Sources/AllSetCore/Clipboard` | 3 | 0 | 3 |
| `Sources/AllSetCore/Developer` | 2 | 0 | 2 |
| `Sources/AllSetCore/Knock` | 5 | 0 | 5 |
| `Sources/AllSetCore/LidPlane` | 5 | 0 | 5 |
| `Sources/AllSetCore/Media` | 3 | 0 | 3 |
| `Sources/AllSetCore/Notch` | 1 | 0 | 1 |
| `Sources/AllSetCore/Notes` | 1 | 0 | 1 |
| `Sources/AllSetCore/Power` | 1 | 0 | 1 |
| `Sources/AllSetCore/Resources/ThemeArt` | 7 | 0 | 7 |
| `Sources/AllSetCore/Screenshot` | 1 | 0 | 1 |
| `Sources/AllSetCore/Search` | 3 | 3 | 0 |
| `Sources/AllSetCore/Settings` | 1 | 0 | 1 |
| `Sources/AllSetCore/Support` | 19 | 18 | 1 |
| `Sources/AllSetCore/System` | 14 | 0 | 14 |
| `Sources/AllSetCore/Themes` | 10 | 0 | 10 |
| `Sources/AllSetCore/Wallpaper` | 4 | 0 | 4 |
| `Sources/AllSetCore/Weather` | 1 | 0 | 1 |
| `Sources/AllSetCore/Widgets` | 17 | 5 | 12 |
| `Sources/AllSetCore/Workspace` | 3 | 0 | 3 |
| `Sources/CPrivateAPIs` | 1 | 0 | 1 |
| `Sources/CPrivateAPIs/include` | 1 | 0 | 1 |
| `Sources/MediaHelper` | 1 | 0 | 1 |
| `Sources/MediaHelper/include` | 1 | 0 | 1 |
| `Tests/AllSetCoreTests` | 44 | 37 | 7 |
| `design/themes-concepts/2026-10-05` | 4 | 4 | 0 |
| `design/themes-concepts/2026-10-05-cinematic-reference` | 3 | 3 | 0 |
| `design/themes-concepts/2026-10-05-original` | 4 | 4 | 0 |
| `design/wallpaper-concepts` | 1 | 1 | 0 |
| `design/wallpaper-concepts/2026-10-05` | 4 | 4 | 0 |
| `design/wallpaper-concepts/2026-10-05-v2` | 4 | 4 | 0 |
| `design/widgets-concepts` | 1 | 1 | 0 |
| `design/widgets-concepts/2026-10-05` | 2 | 2 | 0 |
| `docs` | 3 | 3 | 0 |
| `docs/reference` | 2 | 2 | 0 |
| **All of the above** | **355** | **228** | **127** |

## Appendix C: inventory of every Swift file that moves, or sits in a folder the brief named

Declarations and imports were read from each file [R]. The columns are made as follows:

- **Primary type:** the type named like the file. Otherwise, the first non-private type used outside the file. Otherwise, the first declaration.
- **Referenced from:** every folder with a file that mentions the primary type as a whole word [R]. A word search can overcount: comments and same-named private types also match. For extension-only files such as `ImageCost.swift` (`extension NSImage`), it lists users of the extended type, not of the file [I].
- `LibraryPages.swift`'s real entry point is `LibraryPicker`, which `WidgetOptionsEditor` opens [R].

| File (current) | Lines | Primary type | Other top-level declarations | Imports | Primary type referenced from (folders) |
|---|---|---|---|---|---|
| `Sources/AllSet/AllSetApp.swift` | 58 | `AllSetApp` | AppCommands | AllSetCore, SwiftUI | (none outside this file) |
| `Sources/AllSet/AppDelegate.swift` | 337 | `AppDelegate` | - | AllSetCore, AppKit, MetalKit | AllSet |
| `Sources/AllSet/AppServices+Themes.swift` | 287 | `ThemePreview` | DesktopUndo, ThemeInstall, AppServices | AllSetCore, AppKit | AllSet |
| `Sources/AllSet/AppServices.swift` | 524 | `AppServices` | UIState, RemovedWidget | AllSetCore, AppKit, Observation | AllSet, AllSet/Clipboard, AllSet/Design, AllSet/Knock, AllSet/LidPlane, AllSet/MenuBar, AllSet/Mixer, AllSet/Notch, AllSet/Screenshot, AllSet/Settings, AllSet/Studio, AllSet/Studio/Themes, AllSet/Wallpaper, AllSet/Widgets, AllSet/Widgets/Design, AllSet/Widgets/Kinds, AllSet/Workspace |
| `Sources/AllSet/Clipboard/ClipboardMonitor.swift` | 245 | `ClipboardMonitor` | TextRecognizer, ShelfDrop | AllSetCore, AppKit, CryptoKit, UniformTypeIdentifiers, Vision | AllSet |
| `Sources/AllSet/Clipboard/ClipboardPages.swift` | 324 | `ClipboardPage` | ClipboardFirstRun, ClipboardSettingsSections, ShelfPage | AllSetCore, AppKit, SwiftUI | AllSet |
| `Sources/AllSet/Clipboard/ClipboardPicker.swift` | 270 | `ClipboardPickerController` | PickerState, PickerPanel, ClipboardPickerView, ClipboardRow | AllSetCore, AppKit, SwiftUI | AllSet/Knock, AllSet/Workspace |
| `Sources/AllSet/Components/Components.swift` | 445 | `StatRing` | StatCard, Sparkline, SparklineShape, LevelBar, UsageBar, Chip, Legend, AudioBars, AudioBarsLayer, ArtworkView, AppIco... | AllSetCore, AppKit, SwiftUI | AllSet/Notch, AllSet/Widgets/Kinds |
| `Sources/AllSet/Components/DriftingImage.swift` | 242 | `DriftingImage` | SpinningImageLayer, SpinningImage | AppKit, SwiftUI | AllSet/Wallpaper, AllSet/Widgets |
| `Sources/AllSet/Components/KeyboardActivatable.swift` | 37 | `KeyboardActivatable` | View | SwiftUI | (none outside this file) |
| `Sources/AllSet/Components/LayerGauges.swift` | 264 | `RingGauge` | RingGaugeLayer, BarGaugeLayer, EnvironmentValues, BarGauge | AppKit, SwiftUI | AllSet/Components, AllSet/Widgets, AllSet/Widgets/Design, AllSet/Widgets/Kinds |
| `Sources/AllSet/Components/LiveLayers.swift` | 981 | `LiveLayerView` | EnvironmentValues, PulsingGlow, PulsingGlowLayer, LiveArtwork, SendableImage, ArtworkCache, LiveArtworkLayer, Equaliz... | AllSetCore, AppKit, CoreImage, SwiftUI | AllSet/Widgets/Kinds |
| `Sources/AllSet/Components/Motion.swift` | 71 | `Motion` | View, MotionModifier, MotionLanguage | AllSetCore, AppKit, SwiftUI | AllSet, AllSet/Clipboard, AllSet/Components, AllSet/Design, AllSet/Knock, AllSet/LidPlane, AllSet/Mixer, AllSet/Notch, AllSet/Notes, AllSet/Screenshot, AllSet/Studio, AllSet/Studio/Themes, AllSet/Wallpaper, AllSet/Widgets, AllSet/Widgets/Design, AllSet/Widgets/Kinds, AllSet/Workspace, AllSetCore/Knock, AllSetCore/LidPlane, AllSetCore/Support, AllSetCore/Widgets |
| `Sources/AllSet/Components/Theme.swift` | 78 | `Theme` | - | AllSetCore, SwiftUI | AllSet, AllSet/Components, AllSet/MenuBar, AllSet/Mixer, AllSet/Notch, AllSet/Notes, AllSet/Studio, AllSet/Studio/Themes, AllSet/Widgets, AllSet/Widgets/Kinds, AllSetCore/Widgets |
| `Sources/AllSet/Design/AppNavigation.swift` | 119 | `NavSection` | NavItem | AllSetCore, SwiftUI | AllSet/Design |
| `Sources/AllSet/Design/CinemaDesign.swift` | 302 | `CinemaArtwork` | CinemaImage, CinemaNavigation, CinemaChip, CinemaIcon, CinematicClockFace, CinemaDial, CinemaWidgetPreview, CinemaWin... | AllSetCore, AppKit, SwiftUI | AllSet, AllSet/Widgets/Kinds |
| `Sources/AllSet/Design/DesignComponents.swift` | 631 | `AppBackground` | PageHeader, PageScaffold, SectionHeader, MetadataRow, HeroSection, MediaCard, MediaRail, PreviewCanvas, GlassPanel, G... | SwiftUI | AllSet/Studio |
| `Sources/AllSet/Design/DesignTokens.swift` | 152 | `DS` | View | SwiftUI | AllSet, AllSet/Clipboard, AllSet/Design, AllSet/LidPlane, AllSet/Notch, AllSet/Notes, AllSet/Screenshot, AllSet/Studio, AllSet/Studio/Themes, AllSet/Wallpaper, AllSet/Widgets, AllSet/Workspace |
| `Sources/AllSet/Design/SearchOverlay.swift` | 128 | `SearchOverlay` | Toast, ToastView | AllSetCore, SwiftUI | AllSet |
| `Sources/AllSet/Design/WindowBackdrop.swift` | 276 | `WindowBackdrop` | LensGlow, LensGlowView, BleedLayout, BleedScrollPage, PageVeil | AppKit, SwiftUI | AllSet, AllSet/Design, AllSet/Studio |
| `Sources/AllSet/Knock/KnockActionRunner.swift` | 208 | `KnockActionRunner` | ScreenOverlay | AllSetCore, AppKit, QuartzCore | AllSet/Knock |
| `Sources/AllSet/Knock/KnockController.swift` | 97 | `KnockController` | KnockAction | AllSetCore, AppKit, Observation | AllSet, AllSet/Knock |
| `Sources/AllSet/Knock/KnockPages.swift` | 606 | `KnockPage` | KnockHeader, KnockDots, KnockRow, ActionIcon, KnockMeter, MeterBars, MeterBarsView, SensitivityControls, KnockActionP... | AllSetCore, AppKit, SwiftUI, UniformTypeIdentifiers | AllSet |
| `Sources/AllSet/LidPlane/LidPlaneCapture.swift` | 88 | `LidPlaneCapture` | - | AppKit, ScreenCaptureKit | AllSet/LidPlane |
| `Sources/AllSet/LidPlane/LidPlaneController.swift` | 610 | `LidPlaneController` | LidPlaneOverlayPanel, DisplayLinkTarget | AllSetCore, AppKit, MetalKit, OSLog, Observation, ScreenCaptureKit | AllSet, AllSet/LidPlane |
| `Sources/AllSet/LidPlane/LidPlaneDisplay.swift` | 30 | `LidPlaneDisplay` | - | AppKit, IOKit | AllSet/LidPlane |
| `Sources/AllSet/LidPlane/LidPlanePage.swift` | 233 | `LidPlanePage` | LidPlanePreview, LidAngleReadout, LidStatusText | AllSetCore, AppKit, SwiftUI | AllSet |
| `Sources/AllSet/LidPlane/LidPlaneRenderChecks.swift` | 45 | `LidPlaneRenderChecks` | - | AppKit, MetalKit | AllSet |
| `Sources/AllSet/LidPlane/LidPlaneRenderer.swift` | 342 | `LidPlaneRenderer` | RetainedFrame | AppKit, MetalKit, MetalPerformanceShaders, OSLog | AllSet, AllSet/LidPlane |
| `Sources/AllSet/MainWindow.swift` | 347 | `AppPage` | MainWindowController, MainCanvasHostingView, MainView, RemovedWidgetBar, FormPage | AllSetCore, AppKit, SwiftUI | AllSet, AllSet/Design, AllSet/Widgets |
| `Sources/AllSet/MenuBar/MenuBarContentView.swift` | 168 | `MenuBarContentView` | MenuBarLabel, MetricRow, MiniNowPlaying | AllSetCore, SwiftUI | AllSet |
| `Sources/AllSet/Mixer/MixerController.swift` | 284 | `MixerController` | AudioApp | AllSetCore, AppKit, CoreAudio, Observation | AllSet, AllSet/Mixer |
| `Sources/AllSet/Mixer/MixerViews.swift` | 527 | `MixerTab` | OutputPane, DeviceRow, AppsPane, NotchAppRow, PermissionNote, MixerSlider, ScrollWheelCatcher, SoundMixerPage, AppVol... | AllSetCore, AppKit, SwiftUI | AllSet/Notch |
| `Sources/AllSet/Notch/CollapsedActivityView.swift` | 120 | `CollapsedActivityView` | - | AllSetCore, SwiftUI | AllSet/Mixer, AllSet/Notch |
| `Sources/AllSet/Notch/ExpandedPanel.swift` | 159 | `ExpandedPanel` | NotchTabButton, BatteryBadge | AllSetCore, SwiftUI | AllSet/Notch, AllSet/Widgets |
| `Sources/AllSet/Notch/HomeTab.swift` | 209 | `HomeTab` | NowPlayingCard, MediaControlButton, PlaybackScrubber, QuickStats | AllSetCore, SwiftUI | AllSet/Notch, AllSet/Widgets |
| `Sources/AllSet/Notch/IslandPages.swift` | 292 | `IslandPage` | IslandStage, MonitorPage, MetricTile | AllSetCore, SwiftUI | AllSet |
| `Sources/AllSet/Notch/IslandView.swift` | 215 | `IslandView` | FlippedView, IslandRepresentable | AllSetCore, AppKit, SwiftUI | AllSet/Notch, AllSet/Widgets |
| `Sources/AllSet/Notch/MemoryViews.swift` | 170 | `TopAppsCard` | MemoryActions, MemoryAppsList, MemoryAppRow | AllSetCore, AppKit, SwiftUI | AllSet/Notch, AllSet/Widgets |
| `Sources/AllSet/Notch/NotchAnimation.swift` | 85 | `NotchAnimation` | RevealEffect, RetractEffect, SlideEffect, AnyTransition | SwiftUI | AllSet/Components, AllSet/Notch, AllSet/Widgets |
| `Sources/AllSet/Notch/NotchController.swift` | 441 | `NotchController` | NotchDemo | AllSetCore, AppKit, SwiftUI | AllSet, AllSet/Notch |
| `Sources/AllSet/Notch/NotchPanel.swift` | 81 | `NotchPanel` | FirstClickHostingView, NSScreen, WidgetInstance | AllSetCore, AppKit, SwiftUI | AllSet/Notch |
| `Sources/AllSet/Notch/NotchRootView.swift` | 41 | `NotchRootView` | - | AllSetCore, SwiftUI | AllSet/Notch, AllSet/Widgets |
| `Sources/AllSet/Notch/NotchShape.swift` | 37 | `NotchShape` | - | SwiftUI | AllSet/Notch |
| `Sources/AllSet/Notch/NotchViewModel.swift` | 107 | `NotchViewModel` | LiveActivity | AllSetCore, CoreGraphics, Observation | AllSet/Knock, AllSet/Notch, AllSet/Notes, AllSet/Widgets |
| `Sources/AllSet/Notch/SystemTab.swift` | 291 | `SystemTab` | CPUCard, GPUCard, MemoryCard, NetworkCard, DiskCard, BatteryCard, CPUHistoryCard, CoreBars | AllSetCore, SwiftUI | AllSet, AllSet/Notch, AllSet/Widgets |
| `Sources/AllSet/Notch/TrayTab.swift` | 238 | `TrayTab` | ShelfPane, ShelfTile, ShelfActions, RecentClipboardPane | AllSetCore, AppKit, SwiftUI | AllSet/Notch |
| `Sources/AllSet/Notes/NotesViews.swift` | 267 | `NotesTab` | NoteRow, NotesPage | AllSetCore, AppKit, SwiftUI | AllSet/Notch |
| `Sources/AllSet/Screenshot/ScreenshotShortcutController.swift` | 87 | `ScreenshotShortcutController` | - | AllSetCore, AppKit, Observation | AllSet |
| `Sources/AllSet/Screenshot/ScreenshotStudio.swift` | 421 | `ScreenshotStudioController` | ScreenshotStudioView, AIPanel, ShortcutPicker, ScreenshotPage | AllSetCore, AppKit, Observation, SwiftUI, UniformTypeIdentifiers | AllSet/Knock, AllSet/Notch, AllSet/Screenshot |
| `Sources/AllSet/Settings/DataAndPrivacy.swift` | 210 | `AppData` | DataPrivacySettings | AllSetCore, AppKit, SwiftUI | AllSet |
| `Sources/AllSet/Settings/LaunchAtLogin.swift` | 19 | `LaunchAtLogin` | - | AppKit, ServiceManagement, SwiftUI | AllSet/Settings |
| `Sources/AllSet/Settings/SettingsView.swift` | 155 | `GeneralSettings` | SettingsIcon, NotchSettings, ActivitySettings, AboutSettings | AllSetCore, SwiftUI | AllSet |
| `Sources/AllSet/Settings/WidgetSettings.swift` | 56 | `WidgetSettings` | - | AllSetCore, AppKit, SwiftUI | AllSet |
| `Sources/AllSet/Studio/CinematicCatalog.swift` | 131 | `CinematicCatalog` | CatalogLibraryCard | AllSetCore, SwiftUI | AllSet/Studio |
| `Sources/AllSet/Studio/CinematicWidgets.swift` | 338 | `GalleryPage` | - | AllSetCore, AppKit, SwiftUI | AllSet |
| `Sources/AllSet/Studio/FavoritesPage.swift` | 52 | `FavoritesPage` | - | AllSetCore, SwiftUI | AllSet |
| `Sources/AllSet/Studio/LibraryPages.swift` | 834 | `WebPhotosPage` | LibraryContext, LibraryTile, TileButton, ArtLibraryPage, ArtHero, PaletteFilter, SearchBar, TopicChips, SearchFilters... | AllSetCore, AppKit, SwiftUI, UniformTypeIdentifiers | AllSet/Widgets |
| `Sources/AllSet/Studio/LibraryWidgetPreview.swift` | 111 | `LibraryWidgetPreview` | LibraryPreviewCache, LibraryScrollActivity | AllSetCore, AppKit, CryptoKit, SwiftUI | AllSet/Studio |
| `Sources/AllSet/Studio/StudioThemeStyle.swift` | 82 | `StudioAtmosphere` | StudioFilterSurface, StudioSegmentedControl | AllSetCore, SwiftUI | AllSet, AllSet/Wallpaper |
| `Sources/AllSet/Studio/ThemePreviews.swift` | 592 | `ThemeComposition` | CompositionShadow, ThemeWallpaper, ThemeCardComposition, ThemePreviewVariant, ThemePreviewCache | AllSetCore, AppKit, CoreImage, OSLog, Observation, SwiftUI | AllSet/Studio, AllSet/Widgets |
| `Sources/AllSet/Studio/ThemeWidgetGallery.swift` | 96 | `ThemeWidgetCard` | ThemeWidgetRails | AllSetCore, SwiftUI | AllSet/Studio |
| `Sources/AllSet/Studio/Themes/CardHalo.swift` | 55 | `CardHalo` | - | AppKit, SwiftUI | AllSet/Studio, AllSet/Studio/Themes, AllSet/Wallpaper |
| `Sources/AllSet/Studio/Themes/CarouselProbe.swift` | 237 | `PageCPUProbe` | - | AllSetCore, AppKit, OSLog, SwiftUI | AllSet, AllSet/Widgets |
| `Sources/AllSet/Studio/Themes/CategoryRail.swift` | 64 | `CategoryRail` | - | SwiftUI | AllSet/Studio/Themes |
| `Sources/AllSet/Studio/Themes/HeroCarousel.swift` | 339 | `HeroCarousel` | ThemesMotion, CarouselCardEffect, CarouselScrollCatcher | AllSetCore, AppKit, SwiftUI | AllSet/Studio/Themes |
| `Sources/AllSet/Studio/Themes/ThemeAtmosphere.swift` | 161 | `ThemeAtmosphere` | AppServices, ThemeAtmosphereState | AllSetCore, SwiftUI | AllSet/Studio |
| `Sources/AllSet/Studio/Themes/ThemePreviewCard.swift` | 64 | `ThemePreviewCard` | - | AllSetCore, SwiftUI | AllSet/Studio/Themes, AllSet/Widgets |
| `Sources/AllSet/Studio/Themes/ThemeRail.swift` | 216 | `ThemeRail` | RailCard, ThemeMoodboards | AllSetCore, SwiftUI | AllSet/Studio |
| `Sources/AllSet/Studio/Themes/ThemesFilterBar.swift` | 59 | `ThemesFilterBar` | - | SwiftUI | AllSet/Studio |
| `Sources/AllSet/Studio/Themes/ThemesHero.swift` | 152 | `ThemesHero` | ThemeHeroState | AllSetCore, SwiftUI | AllSet/Studio, AllSet/Studio/Themes |
| `Sources/AllSet/Studio/ThemesPage.swift` | 806 | `ThemesPage` | ThemeDiscovery, DesktopUndoBanner, ThemeSetCard, ThemeSnapshot, ThemeDetailPage, MotionPreview, WidgetColor | AllSetCore, AppKit, SwiftUI | AllSet, AllSet/Widgets |
| `Sources/AllSet/Studio/WidgetOptionsEditor.swift` | 1666 | `WidgetOptionsEditor` | ImageStrip, ArtPicker, TextStylePicker, TimeZonePicker, TintPicker, CalendarAccessRow, CitySearch, BackgroundPhotoPic... | AllSetCore, AppKit, SwiftUI | AllSet/Studio |
| `Sources/AllSet/Studio/WidgetStudio.swift` | 402 | `StudioBackdrop` | GalleryCard, WidgetInspector, DesktopWidgetsPage, DesktopWidgetCard | AllSetCore, AppKit, SwiftUI | AllSet/Notch, AllSet/Studio, AllSet/Widgets |
| `Sources/AllSet/Wallpaper/DesktopCoverage.swift` | 26 | `DesktopCoverage` | - | AllSetCore, AppKit | AllSet/Wallpaper |
| `Sources/AllSet/Wallpaper/WallpaperAtmosphere.swift` | 8 | `WallpaperAtmosphere` | - | SwiftUI | AllSet |
| `Sources/AllSet/Wallpaper/WallpaperController.swift` | 623 | `WallpaperController` | WallpaperScreenState, WallpaperWindow, WallpaperRoot, WallpaperView, MovingPhoto, MovingStill, LoopingVideo, SharedVi... | AVFoundation, AllSetCore, AppKit, OSLog, SwiftUI | AllSet |
| `Sources/AllSet/Wallpaper/WallpaperPages.swift` | 982 | `ClassicWallpaperPage` | WallpaperHero, VideosSection, VideoTile, LibrarySection, FreeUpSpaceRow, LibraryTile, LibraryDetailSheet, WallpaperOp... | AVFoundation, AllSetCore, AppKit, SwiftUI | AllSet, AllSet/Widgets |
| `Sources/AllSet/Widgets/ArtShader.swift` | 838 | `ArtGPU` | MetalArtView, ArtUniforms, ArtItems, ArtShaderSource | AllSetCore, AppKit, Metal, MetalKit, OSLog, SwiftUI | AllSet, AllSet/Widgets |
| `Sources/AllSet/Widgets/ArtView.swift` | 889 | `ArtView` | EnvironmentValues, ArtRenderer | AllSetCore, SwiftUI | AllSet/Studio, AllSet/Wallpaper, AllSet/Widgets, AllSet/Widgets/Kinds |
| `Sources/AllSet/Widgets/Backgrounds.swift` | 139 | `PhotoBackground` | MeshBackground, Grain | AllSetCore, AppKit, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Design/DesignSurface.swift` | 272 | `DesignSurface` | WidgetGlassEffect, GridLines, ScanLines, CornerMarks, WidgetColor | AllSetCore, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Design/WidgetComponents.swift` | 424 | `WidgetMetrics` | WidgetIcon, WidgetHeader, WidgetMetric, WidgetFooter, WidgetBar, WidgetRing, WidgetSparkline, WidgetDivider, WidgetSt... | AllSetCore, SwiftUI | AllSet/Widgets/Kinds |
| `Sources/AllSet/Widgets/Design/WidgetStyle.swift` | 179 | `WidgetStyle` | EnvironmentValues, ThemeWeight, ThemeManager, WidgetColor | AllSetCore, AppKit, SwiftUI | AllSet/Studio, AllSet/Widgets/Design |
| `Sources/AllSet/Widgets/Design/WidgetWord.swift` | 78 | `WidgetWord` | EnvironmentValues, WidgetWordsKey, WidgetTextCase, FootnoteStyle.Alignment, WidgetFootnote | AllSetCore, SwiftUI | AllSet/Components, AllSet/Widgets/Design, AllSet/Widgets/Kinds |
| `Sources/AllSet/Widgets/DesktopWidgetController.swift` | 670 | `DesktopWidgetController` | WidgetDragPhase, WidgetRoot | AllSetCore, AppKit, SwiftUI | AllSet, AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/AestheticWidgets.swift` | 517 | `PhotoWidget` | TextStyle, View, Typeface, Sprockets, PhotoContent, AmbientWidget, QuoteWidget, CountdownWidget | AllSetCore, AppKit, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/CalendarWidget.swift` | 174 | `CalendarWidget` | EventRow, MonthGrid | AllSetCore, SwiftUI | AllSet/Widgets, AllSet/Widgets/Kinds |
| `Sources/AllSet/Widgets/Kinds/CinematicWidgetFace.swift` | 221 | `CinematicWidgetFace` | - | AllSetCore, AppKit, SwiftUI | AllSet/Studio, AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/ClockWidget.swift` | 566 | `ClockWidget` | TimeLabel, FlipTile, StackedTime, AnalogFace, DayProgress, TimeZoneName, WidgetDateFormat | AllSetCore, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/DarkWidgets.swift` | 309 | `NeonSignWidget` | TerminalWidget, BlinkingCursorLayer, DotsWidget, DotGrid, BlinkingCursor | AllSetCore, AppKit, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/DaylightWidget.swift` | 383 | `DaylightWidget` | DaylightScene, SunArc, SunDisc, Hills, SkyPalette | AllSetCore, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/DecorWidgets.swift` | 235 | `ShortcutsWidget` | ShortcutButton, ShortcutLauncher, StickerWidget, StickerArt, Color | AllSetCore, AppKit, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/DeveloperWidgets.swift` | 388 | `GitHubWidget` | RunBadge, ContributionGraph, StatusWidget | AllSetCore, AppKit, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/FocusWidgets.swift` | 533 | `TodoWidget` | FocusWidget, StopwatchWidget, Color, TickingTextLayer, TickingText | AllSetCore, AppKit, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/FootballWidgets.swift` | 996 | `JerseyWidget` | FootballBackdrop, ShirtArt, ShirtShape, PlayerCardWidget, CardPalette, Color, PlayerCardArt, PlayerCardShape, PitchWi... | AllSetCore, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/LifestyleAndAestheticWidgets.swift` | 299 | `AirQualityWidget` | AQIScale, RetroWindowWidget, EnsoWidget, EnsoStroke, MagazineWidget | AllSetCore, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/MusicWidgets.swift` | 625 | `CassetteWidget` | MediaButtons, CassetteArt, ReelHub, VHSWidget, Scanlines, VisualizerWidget, TicketWidget, TicketArt, TicketShape, Bar... | AllSetCore, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/MysticWidgets.swift` | 1030 | `SpiralWidget` | TurningSpiral, SpiralPath, SpiralLayer, CharmWidget, ChromeCharm, CharmOutline, LabelWidget, AuraWidget, AuraField, A... | AllSetCore, AppKit, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/PolaroidsWidget.swift` | 127 | `PolaroidsWidget` | PolaroidPrint | AllSetCore, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/ProductivityWidgets.swift` | 590 | `DateWidget` | NextEventWidget, GoalsWidget, HabitsWidget, ReadingWidget, BookCover | AllSetCore, AppKit, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/SceneWidgets.swift` | 643 | `LockScreenWidget` | SubjectCutout, VinylWidget, Record, MoonWidget, NightSky, Starfield, MoonDisc | AllSetCore, AppKit, CoreImage, SwiftUI, Vision | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/SystemMetricWidget.swift` | 475 | `SystemMetricWidget` | StatusCheckRow, WidgetCoreBars | AllSetCore, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/SystemWidgets.swift` | 422 | `SystemWidget` | BatteryWidget, BatteryRing, NowPlayingWidget, NoteWidget, SampleTrack | AllSetCore, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/Kinds/WeatherWidget.swift` | 376 | `WeatherWidget` | TemperatureCurve, TemperatureRange, SkyBackground, WeatherSymbol | AllSetCore, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/PageCPUProbe.swift` | 902 | `PageCPUProbe` | ProbeOcclusion, ProbeOccludedWidget | AllSetCore, AppKit, SwiftUI | AllSet, AllSet/Studio/Themes, AllSet/Widgets |
| `Sources/AllSet/Widgets/WidgetGridOverlay.swift` | 210 | `WidgetGridOverlay` | WidgetGridOverlayView | AllSetCore, AppKit, QuartzCore | AllSet/Widgets |
| `Sources/AllSet/Widgets/WidgetHostView.swift` | 900 | `WidgetHostView` | EnvironmentValues, WidgetMenuActions, WidgetMenuItems, Color, WidgetColor, WidgetFont, WidgetInstance, ThemedShadow, ... | AllSetCore, AppKit, SwiftUI | AllSet/Widgets |
| `Sources/AllSet/Widgets/WidgetRenderHarness.swift` | 798 | `WidgetRenderHarness` | UnconstrainedWindow | AllSetCore, AppKit, Observation, SwiftUI | AllSet |
| `Sources/AllSet/Widgets/WidgetWindow.swift` | 68 | `WidgetWindow` | WidgetWindowState | AllSetCore, AppKit, Observation | AllSet/Widgets |
| `Sources/AllSet/Workspace/Accessibility.swift` | 204 | `Accessibility` | NativeTiling, AXWindow, HotKeyCenter | AllSetCore, AppKit, ApplicationServices, Carbon.HIToolbox | AllSet/Clipboard, AllSet/Knock, AllSet/Notch, AllSet/Workspace, AllSetCore/Clipboard, AllSetCore/Knock, AllSetCore/Workspace |
| `Sources/AllSet/Workspace/WindowManager.swift` | 266 | `WindowManager` | SnapPreview, SnapPreviewShape | AllSetCore, AppKit, SwiftUI | AllSet, AllSet/Workspace |
| `Sources/AllSet/Workspace/WorkspaceController.swift` | 164 | `WorkspaceController` | - | AllSetCore, AppKit | AllSet |
| `Sources/AllSet/Workspace/WorkspacePages.swift` | 561 | `WindowSnappingPage` | WorkspacesPage, WorkspaceCard, SaveWorkspaceSheet, AccessibilityBanner, WorkspaceIcon, LayoutMiniMap, LayoutGlyph, Sh... | AllSetCore, AppKit, SwiftUI | AllSet |
| `Sources/AllSetCore/AI/AIImageEditors.swift` | 349 | `AIProvider` | AIKeychain, AIEditError, SendableImage, TokenUsage, ClaudeSession, ClaudeReply, ClaudeImageEditor, OpenAIImageEditor | AppKit, Foundation, Security | AllSet/Screenshot, AllSetCore/AI |
| `Sources/AllSetCore/AI/ScreenshotEdit.swift` | 214 | `ScreenshotEdit` | EditPlan, ScreenshotRenderer | AppKit, CoreImage, Foundation | AllSetCore/AI, AllSetCoreTests |
| `Sources/AllSetCore/AI/ScreenshotStudio.swift` | 273 | `ScreenshotStudio` | ScreenshotAI | CoreGraphics, Foundation, ImageIO, Observation | AllSet/Screenshot, AllSetCoreTests |
| `Sources/AllSetCore/Aesthetics/Art.swift` | 323 | `ArtPiece` | ArtStyle, ArtPalette, WidgetColor, Affirmations | Foundation | AllSet/Notch, AllSet/Studio, AllSet/Wallpaper, AllSet/Widgets, AllSet/Widgets/Kinds, AllSetCore/Aesthetics, AllSetCore/Search, AllSetCore/Wallpaper, AllSetCore/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Aesthetics/CuratedBackgrounds.swift` | 219 | `CuratedBackgrounds` | BackgroundCollection | Foundation | AllSet/Studio, AllSet/Widgets, AllSet/Widgets/Kinds, AllSetCore/Aesthetics, AllSetCore/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Aesthetics/ImageLibrary.swift` | 634 | `ImageLibrary` | ImageSource, WebPhoto | AppKit, ImageIO, OSLog, Observation, UniformTypeIdentifiers | AllSet, AllSet/Components, AllSet/Studio, AllSet/Wallpaper, AllSet/Widgets, AllSet/Widgets/Kinds, AllSetCoreTests |
| `Sources/AllSetCore/Aesthetics/LicensedPhotos.swift` | 497 | `CuratedBackgrounds` | - | Foundation | AllSet/Studio, AllSet/Widgets, AllSet/Widgets/Kinds, AllSetCore/Aesthetics, AllSetCore/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Aesthetics/PhotoSearch.swift` | 470 | `PhotoSearch` | - | CoreGraphics, Foundation, OSLog, Observation | AllSet, AllSet/Studio, AllSet/Widgets, AllSetCore/Aesthetics, AllSetCoreTests |
| `Sources/AllSetCore/Aesthetics/Wallhaven.swift` | 131 | `Wallhaven` | - | CoreGraphics, Foundation | AllSet/Studio, AllSetCore/Aesthetics, AllSetCore/Search, AllSetCoreTests |
| `Sources/AllSetCore/Aesthetics/WallpaperColor.swift` | 51 | `WallpaperColor` | - | CoreGraphics, Foundation, ImageIO | AllSet/Studio, AllSet/Widgets/Design, AllSetCoreTests |
| `Sources/AllSetCore/Audio/AppAudioTap.swift` | 377 | `AppAudioTap` | AudioRoutingError, GainBox, AppAudioRouter | CPrivateAPIs, CoreAudio, Foundation, OSLog | AllSetCore/Audio, AllSetCoreTests |
| `Sources/AllSetCore/Audio/AppVolumeStore.swift` | 146 | `AppVolumeStore` | AppVolume, AudioPassthrough | CoreAudio, Foundation, OSLog, Observation | AllSet, AllSet/Mixer, AllSetCoreTests |
| `Sources/AllSetCore/Audio/AudioCapturePermission.swift` | 51 | `AudioCapturePermission` | - | Foundation | AllSet/Mixer, AllSetCoreTests |
| `Sources/AllSetCore/Audio/AudioProcesses.swift` | 123 | `AudioProcesses` | AudioProcess, AudioPropertyListener, AudioProperty | CoreAudio, Foundation | AllSet/Mixer, AllSetCoreTests |
| `Sources/AllSetCore/Audio/VolumeMonitor.swift` | 270 | `VolumeMonitor` | AudioDeviceKind, AudioOutputDevice | AudioToolbox, CoreAudio, Foundation, Observation | AllSet, AllSet/Mixer, AllSetCoreTests |
| `Sources/AllSetCore/Search/AestheticSearch.swift` | 268 | `AestheticSearch` | SearchPacer | Foundation | AllSet/Studio, AllSetCore/Aesthetics, AllSetCore/Search, AllSetCoreTests |
| `Sources/AllSetCore/Search/SearchMatch.swift` | 83 | `SearchMatch` | - | Foundation | AllSet/Design, AllSet/Knock, AllSet/Studio, AllSetCore/Aesthetics, AllSetCore/Clipboard, AllSetCore/Search, AllSetCore/Themes, AllSetCore/Wallpaper, AllSetCore/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Search/WallpaperQuery.swift` | 221 | `WallpaperQuery` | - | Foundation | AllSetCore/Aesthetics, AllSetCoreTests |
| `Sources/AllSetCore/Support/AdminGate.swift` | 24 | `AdminGate` | - | Foundation, LocalAuthentication | AllSet/Wallpaper, AllSetCore/Wallpaper |
| `Sources/AllSetCore/Support/CommandRunner.swift` | 215 | `CommandRunner` | - | Darwin, Foundation | AllSet/Knock, AllSet/Notch, AllSet/Screenshot, AllSetCoreTests |
| `Sources/AllSetCore/Support/ContainedPath.swift` | 54 | `ContainedPath` | - | Foundation | AllSetCore/Clipboard, AllSetCore/Support, AllSetCore/Wallpaper, AllSetCoreTests |
| `Sources/AllSetCore/Support/CostCache.swift` | 72 | `CostCache` | - |  | AllSet/Components, AllSet/Design, AllSet/Studio, AllSetCore/Aesthetics, AllSetCoreTests |
| `Sources/AllSetCore/Support/DataArchive.swift` | 382 | `DataArchive` | - | CryptoKit, Foundation | AllSet/Settings, AllSetCoreTests |
| `Sources/AllSetCore/Support/DeepLink.swift` | 58 | `DeepLink` | - | Foundation | AllSet, AllSetCoreTests |
| `Sources/AllSetCore/Support/DisplayIdentity.swift` | 34 | `DisplayIdentity` | DisplayInfo | Foundation | AllSet/Notch, AllSet/Wallpaper, AllSetCore/Settings, AllSetCore/Widgets, AllSetCore/Workspace, AllSetCoreTests |
| `Sources/AllSetCore/Support/FileDigest.swift` | 21 | `FileDigest` | - | CryptoKit, Foundation | AllSetCore/Wallpaper |
| `Sources/AllSetCore/Support/Format.swift` | 82 | `Format` | TemperatureUnit | Foundation | AllSet/Components, AllSet/MenuBar, AllSet/Notch, AllSet/Widgets/Kinds, AllSetCore/Calendar, AllSetCoreTests |
| `Sources/AllSetCore/Support/ImageCost.swift` | 18 | `NSImage` | - | AppKit | AllSet/Clipboard, AllSet/Components, AllSet/Design, AllSet/Screenshot, AllSet/Studio, AllSet/Studio/Themes, AllSet/Wallpaper, AllSet/Widgets, AllSet/Widgets/Kinds, AllSetCore/Aesthetics, AllSetCore/Clipboard, AllSetCore/Media, scripts |
| `Sources/AllSetCore/Support/KeychainItem.swift` | 41 | `KeychainItem` | - | Foundation, Security | AllSetCore/AI, AllSetCore/Developer, AllSetCoreTests |
| `Sources/AllSetCore/Support/LineReader.swift` | 25 | `LineReader` | - | Foundation | AllSetCore/Media, AllSetCoreTests |
| `Sources/AllSetCore/Support/NeededTimer.swift` | 38 | `NeededTimer` | - | Foundation | AllSet/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Support/PerformancePolicy.swift` | 67 | `PerformancePolicy` | - | Foundation | AllSet, AllSet/Studio/Themes, AllSet/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Support/RetryBackoff.swift` | 36 | `RetryBackoff` | - | Foundation | AllSetCore/Developer, AllSetCore/Weather, AllSetCoreTests |
| `Sources/AllSetCore/Support/RollingSeries.swift` | 20 | `RollingSeries` | - |  | AllSet/Notch, AllSetCore/System, AllSetCoreTests |
| `Sources/AllSetCore/Support/ScreenCoverage.swift` | 20 | `ScreenCoverage` | - | CoreGraphics | AllSet/Wallpaper, AllSetCoreTests |
| `Sources/AllSetCore/Support/SharedRequests.swift` | 49 | `SharedRequests` | - | Foundation | AllSetCore/Developer, AllSetCore/Weather, AllSetCoreTests |
| `Sources/AllSetCore/Support/StoreFile.swift` | 39 | `StoreFile` | - | Foundation, OSLog | AllSetCore/Audio, AllSetCore/Clipboard, AllSetCore/Knock, AllSetCore/Notes, AllSetCore/Themes, AllSetCore/Wallpaper, AllSetCore/Widgets, AllSetCore/Workspace, AllSetCoreTests |
| `Sources/AllSetCore/Themes/DesktopJournal.swift` | 154 | `DesktopJournal` | PendingPreview, PreviewRestore, PreviousDesktop | Foundation, OSLog | AllSet, AllSetCoreTests |
| `Sources/AllSetCore/Themes/DesktopSnapshot.swift` | 76 | `DesktopSnapshot` | AppSettings | Foundation | AllSet, AllSetCore/Themes, AllSetCoreTests |
| `Sources/AllSetCore/Themes/ThemeAccent.swift` | 57 | `ThemeAccent` | WidgetColor | Foundation | AllSet/Studio/Themes, AllSetCore/Themes, AllSetCoreTests |
| `Sources/AllSetCore/Themes/ThemeCardArt.swift` | 127 | `ThemeCardArt` | - | CoreGraphics | AllSet/Studio, AllSetCoreTests |
| `Sources/AllSetCore/Themes/ThemeCarouselLayout.swift` | 62 | `ThemeCarouselLayout` | ThemeCarouselDepth | CoreGraphics, Foundation | AllSet/Studio/Themes, AllSetCoreTests |
| `Sources/AllSetCore/Themes/ThemeLibrary.swift` | 152 | `ThemeLibrary` | - | Foundation | AllSet, AllSet/Design, AllSet/Studio, AllSet/Studio/Themes, AllSet/Widgets, AllSetCore/Themes, AllSetCoreTests |
| `Sources/AllSetCore/Themes/ThemePhotos.swift` | 54 | `ThemePhotos` | - | Foundation, OSLog, Observation | AllSet, AllSet/Studio, AllSetCoreTests |
| `Sources/AllSetCore/Themes/ThemeSet.swift` | 259 | `ThemeSet` | SetItem, ThemeCollection, ThemeResearch | CoreGraphics, Foundation | AllSet, AllSet/Studio, AllSet/Studio/Themes, AllSetCore/Settings, AllSetCore/Themes, AllSetCoreTests |
| `Sources/AllSetCore/Themes/ThemeStats.swift` | 88 | `ThemeStats` | - | Foundation, OSLog, Observation | AllSet, AllSet/Studio, AllSetCoreTests |
| `Sources/AllSetCore/Themes/ThemeWidgetCatalog.swift` | 66 | `ThemeWidgetCatalog` | ThemeWidget | CoreGraphics, Foundation | AllSet/Studio, AllSetCore/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Wallpaper/DeleteAPIKeychain.swift` | 19 | `DeleteAPIKeychain` | - | Foundation | AllSetCore/Wallpaper |
| `Sources/AllSetCore/Wallpaper/WallpaperCategory.swift` | 33 | `WallpaperCategory` | - |  | AllSet/Wallpaper, AllSetCore/Wallpaper, AllSetCoreTests |
| `Sources/AllSetCore/Wallpaper/WallpaperLibrary.swift` | 206 | `LibraryVideo` | WallpaperLibraryCatalog, LibrarySort | Foundation | AllSet/Wallpaper, AllSet/Widgets, AllSetCore/Wallpaper, AllSetCoreTests |
| `Sources/AllSetCore/Wallpaper/WallpaperStore.swift` | 909 | `WallpaperStore` | WallpaperSource, WallpaperMotion, WallpaperConfig, DownloadHandle | Foundation, OSLog, Observation, UniformTypeIdentifiers | AllSet, AllSet/Wallpaper, AllSetCore/Themes, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/DesignTheme.swift` | 438 | `DesignTheme` | WidgetAppearance, RefreshPolicy, RefreshData, SurfaceStyle, MotionLanguage, WallpaperAdaptation, ThemeWeight, ThemePa... | Foundation | AllSet, AllSet/Design, AllSet/Studio, AllSet/Widgets, AllSet/Widgets/Design, AllSetCore/Themes, AllSetCore/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/FanModels.swift` | 253 | `KitPattern` | CardFinish, Formation, PlayerDetails, MatchDetails, TicketDetails, MilestoneDetails, VisualizerStyle, WordArtFinish, ... | Foundation | AllSet/Studio |
| `Sources/AllSetCore/Widgets/FocusTimerCoordinator.swift` | 54 | `FocusTimerCoordinator` | - | Foundation | AllSet, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/MysticModels.swift` | 196 | `CharmShape` | ZodiacSign, TarotCard, AuraReading, MagicAnswers | CoreGraphics, Foundation | AllSet/Studio, AllSet/Widgets/Kinds, AllSetCore/Widgets |
| `Sources/AllSetCore/Widgets/StudioDiscovery.swift` | 119 | `StudioSavedIDs` | StudioWidgetFilter, StudioLayout, StudioWallpaperGrid, StudioScenery | CoreGraphics, Foundation | AllSet/Studio, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/Timers.swift` | 119 | `FocusSession` | StopwatchState | Foundation | AllSet/Widgets/Kinds, AllSetCore/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/WidgetCatalog.swift` | 330 | `WidgetCatalog` | CatalogEntry | Foundation | AllSet/Design, AllSet/Studio, AllSet/Widgets, AllSetCore/Themes, AllSetCore/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/WidgetGrid.swift` | 299 | `WidgetGrid` | WidgetLayout | CoreGraphics | AllSet, AllSet/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/WidgetMath.swift` | 228 | `MoonPhase` | WordClock, Sun, TimeZonePlace | Foundation | AllSet/Widgets/Kinds, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/WidgetModels.swift` | 1467 | `WidgetKind` | WidgetSize, WidgetMaterial, WidgetCategory, PhotoFilter, PhotoFrame, SceneOverlay, QuoteSource, TextStyle, WidgetFont... | CoreGraphics, Foundation | AllSet/Studio, AllSet/Widgets, AllSet/Widgets/Kinds, AllSetCore/Themes, AllSetCore/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/WidgetResize.swift` | 84 | `WidgetResize` | WidgetInstance | CoreGraphics, Foundation | AllSet, AllSet/Studio, AllSet/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/WidgetStore.swift` | 197 | `WidgetStore` | LossyList | Foundation, OSLog, Observation | AllSet, AllSet/Widgets, AllSet/Widgets/Kinds, AllSetCore/Themes, AllSetCore/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/WidgetTheme+Cinematic.swift` | 35 | `WidgetTheme` | - | Foundation | AllSet, AllSet/Studio, AllSet/Widgets, AllSetCore/Themes, AllSetCore/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/WidgetTheme+Colour.swift` | 211 | `WidgetTheme` | - | Foundation | AllSet, AllSet/Studio, AllSet/Widgets, AllSetCore/Themes, AllSetCore/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/WidgetTheme+Fandom.swift` | 658 | `WidgetTheme` | Kit | Foundation | AllSet, AllSet/Studio, AllSet/Widgets, AllSetCore/Themes, AllSetCore/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/WidgetTheme+Moodboards.swift` | 344 | `WidgetTheme` | Kit | Foundation | AllSet, AllSet/Studio, AllSet/Widgets, AllSetCore/Themes, AllSetCore/Widgets, AllSetCoreTests |
| `Sources/AllSetCore/Widgets/WidgetTheme.swift` | 486 | `WidgetTheme` | KitItem, Kit | CoreGraphics, Foundation | AllSet, AllSet/Studio, AllSet/Widgets, AllSetCore/Themes, AllSetCore/Widgets, AllSetCoreTests |
| `Tests/AllSetCoreTests/AestheticsV2Tests.swift` | 174 | `PhotoSearchQualityTests` | WidgetMathTests, SunTests, ImageSizingTests | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/BatteryHealthTests.swift` | 141 | `BatteryHealthTests` | - | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/BatteryTests.swift` | 38 | `BatteryTests` | WallpaperBatteryDefaultTests | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/ClipboardTests.swift` | 247 | `ClipboardStoreTests` | ShelfStoreTests, ClipboardPrivacyTests | CoreGraphics, Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/CommandRunnerTests.swift` | 89 | `CommandRunnerTests` | - | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/ContainedPathTests.swift` | 126 | `ContainedPathTests` | ContainedPathLeakTests | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/CostCacheTests.swift` | 38 | `CostCacheTests` | - | Testing | (none outside this file) |
| `Tests/AllSetCoreTests/DataArchiveTests.swift` | 288 | `DataArchiveTests` | - | CryptoKit, Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/DesktopJournalTests.swift` | 170 | `DesktopJournalTests` | - | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/DesktopSnapshotTests.swift` | 145 | `DesktopSnapshotTests` | WidgetStoreInsertTests | CoreGraphics, Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/DisplayIdentityTests.swift` | 68 | `DisplayIdentityTests` | - | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/FandomTests.swift` | 171 | `FandomTests` | ThemePhotosTests, ScreenCoverageTests, CalmReadingsTests, FitToScreenTests | CoreGraphics, Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/FocusTimerCoordinatorTests.swift` | 54 | `FocusTimerCoordinatorTests` | - | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/GainBoxTests.swift` | 35 | `GainBoxTests` | - | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/HardeningTests.swift` | 181 | `StoreFileTests` | PhotoURLTests | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/ImageImportTests.swift` | 166 | `ImageImportTests` | - | AppKit, Foundation, ImageIO, Testing, UniformTypeIdentifiers | (none outside this file) |
| `Tests/AllSetCoreTests/KeychainItemTests.swift` | 23 | `KeychainItemTests` | - | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/KnockTests.swift` | 323 | `DeterministicNoise` | SyntheticStream, KnockDetectorTests, KnockSettingsTests, Readings | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/LidPlaneTests.swift` | 287 | `LidPlaneAutoAnchorTests` | LidPlaneMotionPolicyTests, LidPlaneSettingsTests, LidPlaneTrackingTests | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/MixerTests.swift` | 201 | `Buffers` | AudioPassthroughTests, AppVolumeTests, LiveAudioTests | CoreAudio, Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/MysticTests.swift` | 53 | `MysticTests` | - | CoreGraphics, Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/NeededTimerTests.swift` | 25 | `NeededTimerTests` | - | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/PerformancePolicyTests.swift` | 47 | `PerformancePolicyTests` | - | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/ScreenshotAITests.swift` | 177 | `ScreenshotAITests` | - | AppKit, Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/ScreenshotShortcutTests.swift` | 45 | `ScreenshotShortcutTests` | ScreenshotShortcutSettingTests | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/ScreenshotStudioTests.swift` | 263 | `ScreenshotStudioTests` | - | CoreGraphics, Foundation, ImageIO, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/SearchMatchTests.swift` | 54 | `SearchMatchTests` | StableOrderTests | Testing | (none outside this file) |
| `Tests/AllSetCoreTests/StudioDiscoveryTests.swift` | 223 | `StudioDiscoveryTests` | - | CoreGraphics, Foundation, ImageIO, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/ThemeCarouselLayoutTests.swift` | 253 | `ThemeCarouselLayoutTests` | ThemeCardArtTests, ThemeAccentTests | CoreGraphics, Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/ThemeLibraryTests.swift` | 111 | `ThemeLibraryTests` | ColourThemeTests | CoreGraphics, Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/ThemeWidgetCatalogTests.swift` | 44 | `ThemeWidgetCatalogTests` | - | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/WallpaperLibraryTests.swift` | 714 | `WallpaperLibraryTests` | StubURLProtocol, LibraryServerFetchTests | Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/WallpaperSearchTests.swift` | 123 | `WallpaperQueryTests` | WallhavenTests | CoreGraphics, Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/WidgetGridTests.swift` | 185 | `WidgetGridTests` | WidgetRefitTests | CoreGraphics, Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/WidgetPlatformTests.swift` | 272 | `DesignThemeTests` | CatalogTests, StoreObservationTests, DeveloperDataTests, LifeDataTests, DeepLinkTests | CoreGraphics, Foundation, Observation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/WidgetResizeTests.swift` | 132 | `WidgetResizeTests` | WidgetFootprintTests | CoreGraphics, Foundation, Testing | (none outside this file) |
| `Tests/AllSetCoreTests/WorkspaceTests.swift` | 155 | `WindowLayoutTests` | WorkspaceStoreTests, WorkspaceRestoreReportTests | CoreGraphics, Foundation, Testing | (none outside this file) |
