# File layout restructure: plan

_Status: **proposed, waiting for review.** Nothing has been moved yet. Written 2026-10-14 from `main` at `325c793`._

This change only moves and renames files. No type, function, property or access modifier changes, and no file moves between SwiftPM targets. Every move uses `git mv`. Renaming types is listed separately in [rename-proposals.md](rename-proposals.md) for a later change.

## Summary

| | Count |
|---|---|
| Files moved (all kinds) | 228 |
| Swift files moved | 192 of 269 |
| Swift files renamed (a file name, not a type) | 4 |
| Files whose content changes | 0 Swift files; docs and one script only where a path string changes (Phase 3) |

Every file in `Sources/AllSet` moves, because the target gets the `App/ Design/ Features/ Debug/` top level. In `Sources/AllSetCore`, files move only where they are misplaced.

## Baseline (recorded before any change)

| Check | Result |
|---|---|
| Toolchain | Apple Swift 6.4 (swiftlang-6.4.0.34.1), Xcode 27.0 (27A266a), arm64-apple-macosx27.0.0 |
| `swift build` | Build complete, **0 warnings** |
| `swift test` | **432 tests in 100 suites passed** |
| `-renderPages` image set | Not captured yet. It launches the app, so it runs at the start of Phase 2 from a `main` build. |

## Phase 0 findings: what depends on file paths

| Where | What it depends on | Effect on this plan |
|---|---|---|
| `Package.swift` | Each target is a whole folder (`Sources/AllSet`, `Sources/AllSetCore`, `Tests/AllSetCoreTests`). `AllSetCore` copies `Resources/ThemeArt`. | Moves inside a target don't affect what compiles. `Sources/AllSetCore/Resources/` stays where it is. |
| `ImageLibrary.swift:608`, `StudioDiscovery.swift:116` | `Bundle.module` resource lookups (`ThemeArt`) | Resource paths aren't source paths, so they're unaffected. |
| `Tests/AllSetCoreTests/LiveSystemTests.swift:49` | `#filePath` walks up **exactly three folders** to find `.build/debug/` | **This file must stay at the test root.** If it moved one level down, `helperURL` would turn nil and the test would be silently *disabled* (`.enabled(if: helperURL != nil)`), not failed. |
| SwiftPM / swift-driver | Two files with the same name in one target fail to compile | Checked by script: no target has a duplicate file name after the moves. |
| `scripts/build-app.sh:37,63` | Copies `Documentation/third-party/*` and `Sources/AllSetCore/Resources/ThemeArt` into the app | Neither path moves. |
| `scripts/review-hero.sh:7,39` | `docs/reference/concept2-reference.png` | Updated in the same commit as the docs merge. |
| `scripts/wallpaper_library.py:460,1342` | Comments that cite `docs/wallpaper-import.md` | Comment updated in Phase 3. No Python import changes. |
| `scripts/cloud/migrations/0001_initial.sql:4` | Comment citing `Sources/AllSetCore/Wallpaper/WallpaperLibrary.swift` | That file doesn't move, so the migration isn't touched. |
| `scripts/probe-budgets.json` | Text mentions `Documentation/HANDOFF.md` | `HANDOFF.md` stays. |
| `scripts/check-repo-hygiene.sh` | Tracked build output, `*.env`, `.DS_Store`, files over 5 MB | Moves can't change any of these. |
| `.github/workflows/ci.yml`, `release.yml`, `Makefile`, `.vscode/*` | No source or doc paths, only `scripts/*` and `.build/debug/AllSet` | No change needed. |
| `design/widgets-concepts/2026-10-05/asset-manifest.json:3-4` | Repo-relative `design/...` paths | Updated with the docs merge. Later lines hold absolute paths from another machine; those are historical and left alone. |
| `README.md`, `Documentation/HANDOFF.md`, `CONTENT.md`, `docs/*` | Source and doc paths in prose | Updated in Phase 3. |
| `Documentation/Reports/*` | Links to `/Users/nawdddep/Downloads/all-set-mac-app-main/...` | Already dead (another checkout). These are dated snapshots and are **not edited**. |
| App code | Any runtime string pointing at `Documentation/`, `docs/` or `design/` | None found. |

`scripts/` and `Resources/` **do not move**: the build, CI, release and Python tests depend on them, and moving them gains nothing.

## Decisions that differ from the prompt

Each one is a Phase 0 finding that proved a better fit. Q1–Q3 under [Questions before Phase 2](#questions-before-phase-2) ask you to confirm D3, D5 and D10.

**D1. `LibraryPages.swift` goes to `Features/Widgets/Studio/`, not Wallpaper.** It isn't a wallpaper page. It's the Art / Photos / My Photos picker (`LibraryPicker`) that the widget options editor opens (`WidgetOptionsEditor.swift:75, 668, 730, 828`). `MainWindow` has no route to it.

**D2. `AllSetCore/Aesthetics/` becomes `AllSetCore/Imagery/`. It is not folded into Wallpaper.** `ImageLibrary`, `ImageSource`, `CuratedBackgrounds` and `ArtPiece` are used by widgets, `WidgetTheme*`, `ThemeSet`, `ThemePhotos` and Wallpaper alike. They're the app's shared picture layer. `Search/AestheticSearch.swift` and `Search/WallpaperQuery.swift` join it, because their only users are `PhotoSearch`, `Wallhaven` and the picker. Despite its name, `WallpaperQuery` is a photo-search query. After this, wallpaper code lives in exactly two places: `AllSetCore/Wallpaper/` and `Features/Wallpaper/`.

**D3. `DeleteAPIKeychain.swift` stays in `AllSetCore/Wallpaper/`.** Its only user is `WallpaperStore`, and its doc comment says it has the "same shape as `GitHubKeychain`". `GitHubKeychain` (in `Developer/GitHub.swift`) and `AIKeychain` (in `AIImageEditors.swift`) also live with their features. All three use the shared `KeychainItem`, which moves to `Support/Security/`. Moving only this one would break the pattern.

**D4. `AppNavigation.swift` and `SearchOverlay.swift` go to `App/`, not `Design/`.** They are the main window's shell (`NavSection` switches over `AppPage` and reads `AppServices`; the overlay is ⌘K plus toasts), not design-system parts.

**D5. Widget kind folders use the app's own widget categories.** The folders are the nine values of `WidgetKind.category` (`WidgetModels.swift:70`): Time, Productivity, System, Developer, Lifestyle, Aesthetic, Football, Music, Mystic. These are the categories the Widgets gallery shows. Two reasons:
- The category is defined in code, so any widget's folder can be looked up rather than argued about.
- 9 of the 19 files hold widgets from two or three categories. With the prompt's function list (Clock, Calendar, Focus, Weather, Decor/Scenes…), half the placements would be judgment calls.

Mixed files go where most of their lines belong (table below). The real fix, one file per widget, is a content change, so it's proposed in `rename-proposals.md` instead of done here.

**D6. Core folders renamed to pair with features: `Audio/` → `Mixer/`, `AI/` → `Screenshot/`.** Every user of `Audio/` is the Mixer feature, `AppServices` or `MixerTests`. Every user of `AI/` is the Screenshot feature or its tests. With these two moves, all 12 `Features/` folders have a `Core` folder of the same name.

**D7. `Support/` split.** The subfolders are Storage, Security, Concurrency, Performance, Text and Display. "Text" replaces "Formatting" because it also holds `SearchMatch`. Performance is new; it holds `PerformancePolicy`, `NeededTimer`, `CostCache` and `ImageCost`. Two files leave Support for where their users are:
- `RollingSeries` goes to `System/`. It is used only for system-metric sparklines.
- `Search/SearchMatch` goes to `Support/Text/`. It is used by nine features.

`DeepLink.swift` stays at the `Support/` root. It's the `allset://` parser, no group fits it, and one file doesn't justify a folder.

**D8. `WidgetTheme*.swift` (5 files) move from `AllSetCore/Widgets/` to `AllSetCore/Themes/`.** `WidgetTheme`'s doc comment calls it "a whole desktop look". `ThemeSet.Look.setup` wraps it, and `ThemeLibrary` builds theme sets from it. `DesignTheme` stays in `Widgets/`, because it is the widget style engine that `WidgetStyle` resolves. See the Theme table below.

**D9. Seven test files stay at the test root.**
- `TestEnvironment.swift` is a shared helper.
- `LiveSystemTests.swift` must stay because of its `#filePath` lookup.
- `LogicTests`, `NotesAndPDFTests`, `ThemesAndSearchTests`, `WidgetNetworkTests` and `WidgetTests` each test several areas, and no area covers half their lines.

Putting the five mixed files in a folder would misfile most of their suites. Splitting them is proposed in `rename-proposals.md`. `Tests/Support/` stays flat: nine files don't need six subfolders.

**D10. Wallpaper-library docs get a subfolder: `Documentation/wallpaper-library/`.** `spec.md`, `architecture.md`, `report.md`, `operations.md`, `scene-renderer-diagnosis.md` and `docs/wallpaper-import.md` are all about the wallpaper library; the first three even say so in their titles. Moving `architecture.md` there keeps its content and history, and frees `Documentation/architecture.md` to become the app-wide map the prompt asks for, instead of overwriting the wallpaper design record. Three things stay put:
- `HANDOFF.md` stays at the root, because `probe-budgets.json` cites it.
- `third-party/` stays, because `build-app.sh` copies it.
- The root `design/` folder moves to `Documentation/design/`.

**D11. One commit per Phase 2 step (9 commits), on a branch `restructure/file-layout`, not `main`.** The prompt says one commit per phase. One per step means "revert the step that broke the build" is a single `git revert`.

**D12. The genre-named widget files keep their names for now.** Examples are `AestheticWidgets.swift` and `DarkWidgets.swift`. Renaming them to a "primary type" would still mislead; for example, `PhotoWidget` is 44% of `AestheticWidgets.swift`, which also holds `QuoteWidget`, `AmbientWidget` and `CountdownWidget`. A file name that reads oddly inside its new category folder is the signal that the file needs splitting.

### The four file renames

Each follows the rule "rename a file to match its primary type":

| From | To | Why |
|---|---|---|
| `Studio/StudioThemeStyle.swift` | `Design/Backdrop/StudioAtmosphere.swift` | No type is named `StudioThemeStyle`. `StudioAtmosphere` is the main type, used by `MainWindow` and `WallpaperAtmosphere`. |
| `Studio/CinematicWidgets.swift` | `Features/Widgets/Studio/GalleryPage.swift` | `GalleryPage` is the file's only type. |
| `Screenshot/ScreenshotStudio.swift` (app) | `Features/Screenshot/ScreenshotStudioView.swift` | `ScreenshotStudioView` is 295 of its 421 lines. This fixes problem 6: two `ScreenshotStudio.swift` files, one in each target. |
| `Tests/.../HardeningTests.swift` | `Tests/.../Support/StoreFileTests.swift` | `StoreFileTests` is 170 of 181 lines (the rest is a 7-line `PhotoURLTests`). |

## What each "Theme" is

| Type (file after the move) | What it is | Used by |
|---|---|---|
| `Theme` (`AllSet/Design/Tokens/Theme.swift`) | Static colours: metric colours on the black notch, energy-bar warmth, sticky-note paper, the gradients for the widget "Solid" and "Color" styles. A palette, not a theme. | Notch, menu bar, Mixer, Notes, widgets |
| `DesignTheme` (`AllSetCore/Widgets/DesignTheme.swift`) | The widget style engine: card surface, light/dark colours, typography, accent, shadow, motion language. Widgets draw through it rather than styling themselves. Its parts are `ThemePalette`, `ThemeTypography`, `ThemeWeight` and `ThemeShadow`. | `WidgetStyle`, `WidgetHostView`, `DesignSurface`, `ThemeSet` |
| `WidgetTheme` (+`Cinematic`, `Colour`, `Fandom`, `Moodboards`) (`AllSetCore/Themes/`) | The original "aesthetic setups": a desktop look made of a material, colours, a wallpaper and a starter kit of widgets (`Kit`, `KitItem`). The extensions are the four packs. | `ThemeSet`, `ThemeLibrary`, `WidgetStudio`, `AppServices` |
| `ThemeSet` (`AllSetCore/Themes/ThemeSet.swift`) | What the Themes page offers: a complete desktop (visual language, widget layout, wallpaper, motion, origin). Its `Look` is either a `DesignTheme` or a `WidgetTheme`. | Themes feature, `AppServices+Themes` |
| `ThemeManager` (`AllSet/Design/Widget/WidgetStyle.swift`) | Despite the name, it watches the desktop picture's colour (`wallpaperAccent`) for widgets that adapt to the wallpaper. It doesn't manage themes. | `AppServices`, `WidgetStyle` |
| `StudioThemeStyle.swift` (file only) | Holds no theme. It contains `StudioAtmosphere`, `StudioFilterSurface` and `StudioSegmentedControl`, the shared backdrop and controls of the Desktop pages. It's renamed in this change. | `MainWindow`, Wallpaper, Widgets gallery |
| `Studio/Themes/` (folder) | The Themes page UI (hero carousel, rails, filter bar, atmosphere). It becomes `Features/Themes/`. | — |

Type renames that would remove the overlap (for example `Theme` → `AppPalette` and `ThemeManager` → `WallpaperAccentMonitor`) are in [rename-proposals.md](rename-proposals.md). They are not part of this change.

## Target layout

```
Sources/AllSet/
  App/                 AllSetApp, AppDelegate, AppServices(+Themes), MainWindow, AppNavigation, SearchOverlay, MenuBar/
  Design/
    Tokens/            DesignTokens (DS), Theme
    Motion/            Motion, DriftingImage, LiveLayers        (Core Animation movement)
    Components/        Components, DesignComponents, CinemaDesign, LayerGauges, KeyboardActivatable
    Backdrop/          WindowBackdrop, StudioAtmosphere
    Widget/            WidgetStyle, WidgetComponents, DesignSurface, WidgetWord
  Features/
    Clipboard  Knock  LidPlane  Mixer  Notch  Notes  Screenshot  Settings  Workspace
    Wallpaper/         DesktopCoverage, WallpaperAtmosphere, WallpaperController, WallpaperPages
    Themes/            ThemesPage, ThemePreviews, FavoritesPage, ThemeWidgetGallery + hero/rail parts (flat)
    Widgets/           DesktopWidgetController, WidgetHostView, WidgetWindow, WidgetGridOverlay, Backgrounds, ArtShader, ArtView
      Studio/          GalleryPage, CinematicCatalog, WidgetStudio, WidgetOptionsEditor, LibraryWidgetPreview, LibraryPages
      Kinds/           CinematicWidgetFace + Time/ Productivity/ System/ Developer/ Lifestyle/ Aesthetic/ Football/ Music/ Mystic/
  Debug/               PageCPUProbe, WidgetRenderHarness, CarouselProbe   (each still #if DEBUG … #endif)

Sources/AllSetCore/
  Clipboard Knock LidPlane Mixer Notch Notes Screenshot Settings Themes Wallpaper Widgets Workspace   ← same names as Features/
  Calendar Developer Media Power Weather System    data sources the widgets and notch read (no feature of their own)
  Imagery/             image library, photo search, Wallhaven, curated/licensed photos, art, wallpaper colour
  Support/             Storage/ Security/ Concurrency/ Performance/ Text/ Display/ + DeepLink.swift
  Resources/ThemeArt   (unchanged)

Tests/AllSetCoreTests/
  Clipboard Imagery Knock LidPlane Mixer Screenshot Support System Themes Wallpaper Widgets Workspace
  + at the root: TestEnvironment, LiveSystemTests, and the five mixed files (D9)

Documentation/
  README.md (new index)   architecture.md (new app map)   HANDOFF.md   UI-Spec.md   perf-audit.md
  frontend-rules.md (was rules_frontend.md)   content.md (was CONTENT.md)
  restructure-plan.md   rename-proposals.md
  wallpaper-library/   spec, architecture, report, operations, scene-renderer-diagnosis, import
  Reports/   design/ (was root design/ + docs/reference/)   third-party/
```

## Widget kinds: where each file goes and why

Line counts are per category, from each file's declarations. ✱ marks a mixed file; its split is proposed in `rename-proposals.md`.

| File | Widgets it holds (category) | Lines by category | Folder |
|---|---|---|---|
| `ClockWidget` | clock (Time) | Time 566 | Time |
| `CalendarWidget` | calendar (Productivity) | Productivity 174 | Productivity |
| `FocusWidgets` ✱ | todo, focus (Productivity); stopwatch (Time) | Productivity ≈400, Time ≈116 | Productivity |
| `ProductivityWidgets` ✱ | nextEvent, goals, habits (Productivity); date (Time); reading (Lifestyle) | Productivity ≈381, Lifestyle 106, Time 87 | Productivity |
| `SystemWidgets` ✱ | system, battery (System); nowPlaying (Lifestyle); note (Productivity) | System ≈213, Lifestyle ≈162, Productivity 44 | System |
| `SystemMetricWidget` | metric (System) | System 475 | System |
| `DarkWidgets` ✱ | terminal (System); dots (Time); neon (Aesthetic) | System ≈135, Time ≈116, Aesthetic 50 | System |
| `DeveloperWidgets` | github, status (Developer) | Developer 388 | Developer |
| `WeatherWidget` | weather (Lifestyle) | Lifestyle 376 | Lifestyle |
| `DaylightWidget` | daylight (Lifestyle) | Lifestyle 383 | Lifestyle |
| `AestheticWidgets` ✱ | photo, quote (Lifestyle); ambient (Aesthetic); countdown (Time) | Lifestyle ≈328, Aesthetic 51, Time 42 | Lifestyle |
| `SceneWidgets` ✱ | lockScreen, vinyl (Aesthetic); moon (Lifestyle) | Aesthetic ≈454, Lifestyle ≈178 | Aesthetic |
| `PolaroidsWidget` | polaroids (Aesthetic) | Aesthetic 127 | Aesthetic |
| `DecorWidgets` ✱ | sticker (Aesthetic); shortcuts (Productivity) | Aesthetic ≈122, Productivity ≈105 | Aesthetic |
| `LifestyleAndAestheticWidgets` ✱ | retroWindow, enso, magazine (Aesthetic); airQuality (Lifestyle) | Aesthetic ≈184, Lifestyle ≈108 | Aesthetic |
| `FootballWidgets` | jersey, playerCard, pitch, scoreboard, milestone (Football) | Football 996 | Football |
| `MusicWidgets` ✱ | cassette, vhs, visualizer, ticket (Music); wordArt (Aesthetic) | Music ≈510, Aesthetic ≈111 | Music |
| `MysticWidgets` ✱ | aura, tarot, zodiac, eightBall, candle (Mystic); spiral, charm, label (Aesthetic) | Mystic ≈700, Aesthetic ≈315 | Mystic |
| `CinematicWidgetFace` | Alternative face for six kinds across four categories (`supports(_:)`) | — | `Kinds/` root |

## Execution (Phase 2), once approved

1. Create branch `restructure/file-layout` from `main`.
2. Capture the before image set: `.build/debug/AllSet -renderPages <scratch>/before`. This launches the app; the harness quits by itself.
3. Run the steps in this order: 1 Design merge (plus App shell) → 2 Debug harnesses → 3 Studio split → 4 Features and Wallpaper/Imagery → 5 Widget kinds → 6 Core Support split → 7 Screenshot duplicate name → 8 Tests mirror → 9 Documentation merge (with the `review-hero.sh` and `asset-manifest.json` path fixes, so no commit has a broken script).
4. After **each** step:
   - run `swift build` and count `warning:` lines (must be 0);
   - run `swift test` (must be 432 tests in 100 suites);
   - commit only if both pass. If one fails, fix the step, or revert it and report.
5. Phase 3, in one commit:
   - update the paths in `README.md`, `HANDOFF.md`, `content.md`, `UI-Spec.md`, `perf-audit.md`, `wallpaper-library/*` and the `wallpaper_library.py` comments;
   - write the new `Documentation/architecture.md` (app-wide map: title, date, what each folder is for) and `Documentation/README.md` (index).

   Dated reports are not edited.

## Verification (all run for real, results reported with output)

1. A clean `swift build` (`.build` removed first) gives 0 warnings, and `swift test` gives 432 tests in 100 suites.
2. `scripts/check-repo-hygiene.sh` passes.
3. `git diff -M100% --summary main...HEAD -- Sources Tests` lists only `rename` lines, with no `create`/`delete` and no content edits.
4. `-renderPages` gives the same file names and count as before. Pixel hashes are reported too, but clocks and live readings can differ between runs.
5. `grep -rn "Sources/" .github Makefile .vscode` returns nothing, as it does today.
6. CI is green on the pushed branch. **This needs you to approve pushing the branch to `origin`.**

## Questions before Phase 2

1. **Widget kind folders** (D5): use the app's own categories (my recommendation), or the function names from the prompt?
2. **`DeleteAPIKeychain`** (D3): keep it in Wallpaper (my recommendation), or move it to `Support/Security/`?
3. **Wallpaper-library docs subfolder** (D10): OK, or keep them flat at the `Documentation/` root as in the prompt?
4. When the moves are done, may I push `restructure/file-layout` to `origin` so CI runs on it?

## Noticed, out of scope (no action in this change)

- `ThemeWidgetRails` (`ThemeWidgetGallery.swift`) isn't referenced outside its own file, so it may be dead code. `ThemeWidgetCard` in the same file *is* used, by `CinematicCatalog`.
- `SendableImage` is declared in both targets (`LiveLayers.swift` and `AIImageEditors.swift`). The app's copy shadows Core's.
- `LidPlane/EffectDefaults.swift` declares `LidPlaneDefaults`, a file-name mismatch not on the problem list.

## Appendix: every move, current → target

Generated from the move map that the Phase 2 script also uses, so the table and the moves can't disagree. Files not listed stay where they are; Phase 0 found them correctly placed.

### Step 1-design  (24 moves)

| Current | Target |
|---|---|
| `Sources/AllSet/Design/DesignTokens.swift` | `Sources/AllSet/Design/Tokens/DesignTokens.swift` |
| `Sources/AllSet/Components/Theme.swift` | `Sources/AllSet/Design/Tokens/Theme.swift` |
| `Sources/AllSet/Components/Motion.swift` | `Sources/AllSet/Design/Motion/Motion.swift` |
| `Sources/AllSet/Components/DriftingImage.swift` | `Sources/AllSet/Design/Motion/DriftingImage.swift` |
| `Sources/AllSet/Components/LiveLayers.swift` | `Sources/AllSet/Design/Motion/LiveLayers.swift` |
| `Sources/AllSet/Components/Components.swift` | `Sources/AllSet/Design/Components/Components.swift` |
| `Sources/AllSet/Components/KeyboardActivatable.swift` | `Sources/AllSet/Design/Components/KeyboardActivatable.swift` |
| `Sources/AllSet/Components/LayerGauges.swift` | `Sources/AllSet/Design/Components/LayerGauges.swift` |
| `Sources/AllSet/Design/DesignComponents.swift` | `Sources/AllSet/Design/Components/DesignComponents.swift` |
| `Sources/AllSet/Design/CinemaDesign.swift` | `Sources/AllSet/Design/Components/CinemaDesign.swift` |
| `Sources/AllSet/Design/WindowBackdrop.swift` | `Sources/AllSet/Design/Backdrop/WindowBackdrop.swift` |
| `Sources/AllSet/Studio/StudioThemeStyle.swift` | `Sources/AllSet/Design/Backdrop/StudioAtmosphere.swift` |
| `Sources/AllSet/Widgets/Design/WidgetStyle.swift` | `Sources/AllSet/Design/Widget/WidgetStyle.swift` |
| `Sources/AllSet/Widgets/Design/WidgetComponents.swift` | `Sources/AllSet/Design/Widget/WidgetComponents.swift` |
| `Sources/AllSet/Widgets/Design/DesignSurface.swift` | `Sources/AllSet/Design/Widget/DesignSurface.swift` |
| `Sources/AllSet/Widgets/Design/WidgetWord.swift` | `Sources/AllSet/Design/Widget/WidgetWord.swift` |
| `Sources/AllSet/AllSetApp.swift` | `Sources/AllSet/App/AllSetApp.swift` |
| `Sources/AllSet/AppDelegate.swift` | `Sources/AllSet/App/AppDelegate.swift` |
| `Sources/AllSet/AppServices.swift` | `Sources/AllSet/App/AppServices.swift` |
| `Sources/AllSet/AppServices+Themes.swift` | `Sources/AllSet/App/AppServices+Themes.swift` |
| `Sources/AllSet/MainWindow.swift` | `Sources/AllSet/App/MainWindow.swift` |
| `Sources/AllSet/MenuBar/MenuBarContentView.swift` | `Sources/AllSet/App/MenuBar/MenuBarContentView.swift` |
| `Sources/AllSet/Design/AppNavigation.swift` | `Sources/AllSet/App/AppNavigation.swift` |
| `Sources/AllSet/Design/SearchOverlay.swift` | `Sources/AllSet/App/SearchOverlay.swift` |

### Step 2-debug  (3 moves)

| Current | Target |
|---|---|
| `Sources/AllSet/Widgets/PageCPUProbe.swift` | `Sources/AllSet/Debug/PageCPUProbe.swift` |
| `Sources/AllSet/Widgets/WidgetRenderHarness.swift` | `Sources/AllSet/Debug/WidgetRenderHarness.swift` |
| `Sources/AllSet/Studio/Themes/CarouselProbe.swift` | `Sources/AllSet/Debug/CarouselProbe.swift` |

### Step 3-studio  (18 moves)

| Current | Target |
|---|---|
| `Sources/AllSet/Studio/ThemesPage.swift` | `Sources/AllSet/Features/Themes/ThemesPage.swift` |
| `Sources/AllSet/Studio/ThemePreviews.swift` | `Sources/AllSet/Features/Themes/ThemePreviews.swift` |
| `Sources/AllSet/Studio/ThemeWidgetGallery.swift` | `Sources/AllSet/Features/Themes/ThemeWidgetGallery.swift` |
| `Sources/AllSet/Studio/FavoritesPage.swift` | `Sources/AllSet/Features/Themes/FavoritesPage.swift` |
| `Sources/AllSet/Studio/Themes/CardHalo.swift` | `Sources/AllSet/Features/Themes/CardHalo.swift` |
| `Sources/AllSet/Studio/Themes/CategoryRail.swift` | `Sources/AllSet/Features/Themes/CategoryRail.swift` |
| `Sources/AllSet/Studio/Themes/HeroCarousel.swift` | `Sources/AllSet/Features/Themes/HeroCarousel.swift` |
| `Sources/AllSet/Studio/Themes/ThemeAtmosphere.swift` | `Sources/AllSet/Features/Themes/ThemeAtmosphere.swift` |
| `Sources/AllSet/Studio/Themes/ThemePreviewCard.swift` | `Sources/AllSet/Features/Themes/ThemePreviewCard.swift` |
| `Sources/AllSet/Studio/Themes/ThemeRail.swift` | `Sources/AllSet/Features/Themes/ThemeRail.swift` |
| `Sources/AllSet/Studio/Themes/ThemesFilterBar.swift` | `Sources/AllSet/Features/Themes/ThemesFilterBar.swift` |
| `Sources/AllSet/Studio/Themes/ThemesHero.swift` | `Sources/AllSet/Features/Themes/ThemesHero.swift` |
| `Sources/AllSet/Studio/CinematicCatalog.swift` | `Sources/AllSet/Features/Widgets/Studio/CinematicCatalog.swift` |
| `Sources/AllSet/Studio/LibraryWidgetPreview.swift` | `Sources/AllSet/Features/Widgets/Studio/LibraryWidgetPreview.swift` |
| `Sources/AllSet/Studio/WidgetOptionsEditor.swift` | `Sources/AllSet/Features/Widgets/Studio/WidgetOptionsEditor.swift` |
| `Sources/AllSet/Studio/WidgetStudio.swift` | `Sources/AllSet/Features/Widgets/Studio/WidgetStudio.swift` |
| `Sources/AllSet/Studio/LibraryPages.swift` | `Sources/AllSet/Features/Widgets/Studio/LibraryPages.swift` |
| `Sources/AllSet/Studio/CinematicWidgets.swift` | `Sources/AllSet/Features/Widgets/Studio/GalleryPage.swift` |

### Step 4-features  (68 moves)

| Current | Target |
|---|---|
| `Sources/AllSet/Wallpaper/DesktopCoverage.swift` | `Sources/AllSet/Features/Wallpaper/DesktopCoverage.swift` |
| `Sources/AllSet/Wallpaper/WallpaperAtmosphere.swift` | `Sources/AllSet/Features/Wallpaper/WallpaperAtmosphere.swift` |
| `Sources/AllSet/Wallpaper/WallpaperController.swift` | `Sources/AllSet/Features/Wallpaper/WallpaperController.swift` |
| `Sources/AllSet/Wallpaper/WallpaperPages.swift` | `Sources/AllSet/Features/Wallpaper/WallpaperPages.swift` |
| `Sources/AllSetCore/Aesthetics/Art.swift` | `Sources/AllSetCore/Imagery/Art.swift` |
| `Sources/AllSetCore/Aesthetics/CuratedBackgrounds.swift` | `Sources/AllSetCore/Imagery/CuratedBackgrounds.swift` |
| `Sources/AllSetCore/Aesthetics/ImageLibrary.swift` | `Sources/AllSetCore/Imagery/ImageLibrary.swift` |
| `Sources/AllSetCore/Aesthetics/LicensedPhotos.swift` | `Sources/AllSetCore/Imagery/LicensedPhotos.swift` |
| `Sources/AllSetCore/Aesthetics/PhotoSearch.swift` | `Sources/AllSetCore/Imagery/PhotoSearch.swift` |
| `Sources/AllSetCore/Aesthetics/Wallhaven.swift` | `Sources/AllSetCore/Imagery/Wallhaven.swift` |
| `Sources/AllSetCore/Aesthetics/WallpaperColor.swift` | `Sources/AllSetCore/Imagery/WallpaperColor.swift` |
| `Sources/AllSetCore/Search/AestheticSearch.swift` | `Sources/AllSetCore/Imagery/AestheticSearch.swift` |
| `Sources/AllSetCore/Search/WallpaperQuery.swift` | `Sources/AllSetCore/Imagery/WallpaperQuery.swift` |
| `Sources/AllSetCore/Widgets/WidgetTheme.swift` | `Sources/AllSetCore/Themes/WidgetTheme.swift` |
| `Sources/AllSetCore/Widgets/WidgetTheme+Cinematic.swift` | `Sources/AllSetCore/Themes/WidgetTheme+Cinematic.swift` |
| `Sources/AllSetCore/Widgets/WidgetTheme+Colour.swift` | `Sources/AllSetCore/Themes/WidgetTheme+Colour.swift` |
| `Sources/AllSetCore/Widgets/WidgetTheme+Fandom.swift` | `Sources/AllSetCore/Themes/WidgetTheme+Fandom.swift` |
| `Sources/AllSetCore/Widgets/WidgetTheme+Moodboards.swift` | `Sources/AllSetCore/Themes/WidgetTheme+Moodboards.swift` |
| `Sources/AllSet/Clipboard/ClipboardMonitor.swift` | `Sources/AllSet/Features/Clipboard/ClipboardMonitor.swift` |
| `Sources/AllSet/Clipboard/ClipboardPages.swift` | `Sources/AllSet/Features/Clipboard/ClipboardPages.swift` |
| `Sources/AllSet/Clipboard/ClipboardPicker.swift` | `Sources/AllSet/Features/Clipboard/ClipboardPicker.swift` |
| `Sources/AllSet/Knock/KnockActionRunner.swift` | `Sources/AllSet/Features/Knock/KnockActionRunner.swift` |
| `Sources/AllSet/Knock/KnockController.swift` | `Sources/AllSet/Features/Knock/KnockController.swift` |
| `Sources/AllSet/Knock/KnockPages.swift` | `Sources/AllSet/Features/Knock/KnockPages.swift` |
| `Sources/AllSet/LidPlane/LidPlaneCapture.swift` | `Sources/AllSet/Features/LidPlane/LidPlaneCapture.swift` |
| `Sources/AllSet/LidPlane/LidPlaneController.swift` | `Sources/AllSet/Features/LidPlane/LidPlaneController.swift` |
| `Sources/AllSet/LidPlane/LidPlaneDisplay.swift` | `Sources/AllSet/Features/LidPlane/LidPlaneDisplay.swift` |
| `Sources/AllSet/LidPlane/LidPlanePage.swift` | `Sources/AllSet/Features/LidPlane/LidPlanePage.swift` |
| `Sources/AllSet/LidPlane/LidPlaneRenderChecks.swift` | `Sources/AllSet/Features/LidPlane/LidPlaneRenderChecks.swift` |
| `Sources/AllSet/LidPlane/LidPlaneRenderer.swift` | `Sources/AllSet/Features/LidPlane/LidPlaneRenderer.swift` |
| `Sources/AllSet/Mixer/MixerController.swift` | `Sources/AllSet/Features/Mixer/MixerController.swift` |
| `Sources/AllSet/Mixer/MixerViews.swift` | `Sources/AllSet/Features/Mixer/MixerViews.swift` |
| `Sources/AllSet/Notch/CollapsedActivityView.swift` | `Sources/AllSet/Features/Notch/CollapsedActivityView.swift` |
| `Sources/AllSet/Notch/ExpandedPanel.swift` | `Sources/AllSet/Features/Notch/ExpandedPanel.swift` |
| `Sources/AllSet/Notch/HomeTab.swift` | `Sources/AllSet/Features/Notch/HomeTab.swift` |
| `Sources/AllSet/Notch/IslandPages.swift` | `Sources/AllSet/Features/Notch/IslandPages.swift` |
| `Sources/AllSet/Notch/IslandView.swift` | `Sources/AllSet/Features/Notch/IslandView.swift` |
| `Sources/AllSet/Notch/MemoryViews.swift` | `Sources/AllSet/Features/Notch/MemoryViews.swift` |
| `Sources/AllSet/Notch/NotchAnimation.swift` | `Sources/AllSet/Features/Notch/NotchAnimation.swift` |
| `Sources/AllSet/Notch/NotchController.swift` | `Sources/AllSet/Features/Notch/NotchController.swift` |
| `Sources/AllSet/Notch/NotchPanel.swift` | `Sources/AllSet/Features/Notch/NotchPanel.swift` |
| `Sources/AllSet/Notch/NotchRootView.swift` | `Sources/AllSet/Features/Notch/NotchRootView.swift` |
| `Sources/AllSet/Notch/NotchShape.swift` | `Sources/AllSet/Features/Notch/NotchShape.swift` |
| `Sources/AllSet/Notch/NotchViewModel.swift` | `Sources/AllSet/Features/Notch/NotchViewModel.swift` |
| `Sources/AllSet/Notch/SystemTab.swift` | `Sources/AllSet/Features/Notch/SystemTab.swift` |
| `Sources/AllSet/Notch/TrayTab.swift` | `Sources/AllSet/Features/Notch/TrayTab.swift` |
| `Sources/AllSet/Notes/NotesViews.swift` | `Sources/AllSet/Features/Notes/NotesViews.swift` |
| `Sources/AllSet/Settings/DataAndPrivacy.swift` | `Sources/AllSet/Features/Settings/DataAndPrivacy.swift` |
| `Sources/AllSet/Settings/LaunchAtLogin.swift` | `Sources/AllSet/Features/Settings/LaunchAtLogin.swift` |
| `Sources/AllSet/Settings/SettingsView.swift` | `Sources/AllSet/Features/Settings/SettingsView.swift` |
| `Sources/AllSet/Settings/WidgetSettings.swift` | `Sources/AllSet/Features/Settings/WidgetSettings.swift` |
| `Sources/AllSet/Workspace/Accessibility.swift` | `Sources/AllSet/Features/Workspace/Accessibility.swift` |
| `Sources/AllSet/Workspace/WindowManager.swift` | `Sources/AllSet/Features/Workspace/WindowManager.swift` |
| `Sources/AllSet/Workspace/WorkspaceController.swift` | `Sources/AllSet/Features/Workspace/WorkspaceController.swift` |
| `Sources/AllSet/Workspace/WorkspacePages.swift` | `Sources/AllSet/Features/Workspace/WorkspacePages.swift` |
| `Sources/AllSet/Screenshot/ScreenshotShortcutController.swift` | `Sources/AllSet/Features/Screenshot/ScreenshotShortcutController.swift` |
| `Sources/AllSet/Widgets/ArtShader.swift` | `Sources/AllSet/Features/Widgets/ArtShader.swift` |
| `Sources/AllSet/Widgets/ArtView.swift` | `Sources/AllSet/Features/Widgets/ArtView.swift` |
| `Sources/AllSet/Widgets/Backgrounds.swift` | `Sources/AllSet/Features/Widgets/Backgrounds.swift` |
| `Sources/AllSet/Widgets/DesktopWidgetController.swift` | `Sources/AllSet/Features/Widgets/DesktopWidgetController.swift` |
| `Sources/AllSet/Widgets/WidgetGridOverlay.swift` | `Sources/AllSet/Features/Widgets/WidgetGridOverlay.swift` |
| `Sources/AllSet/Widgets/WidgetHostView.swift` | `Sources/AllSet/Features/Widgets/WidgetHostView.swift` |
| `Sources/AllSet/Widgets/WidgetWindow.swift` | `Sources/AllSet/Features/Widgets/WidgetWindow.swift` |
| `Sources/AllSetCore/Audio/AppAudioTap.swift` | `Sources/AllSetCore/Mixer/AppAudioTap.swift` |
| `Sources/AllSetCore/Audio/AppVolumeStore.swift` | `Sources/AllSetCore/Mixer/AppVolumeStore.swift` |
| `Sources/AllSetCore/Audio/AudioCapturePermission.swift` | `Sources/AllSetCore/Mixer/AudioCapturePermission.swift` |
| `Sources/AllSetCore/Audio/AudioProcesses.swift` | `Sources/AllSetCore/Mixer/AudioProcesses.swift` |
| `Sources/AllSetCore/Audio/VolumeMonitor.swift` | `Sources/AllSetCore/Mixer/VolumeMonitor.swift` |

### Step 5-kinds  (19 moves)

| Current | Target |
|---|---|
| `Sources/AllSet/Widgets/Kinds/ClockWidget.swift` | `Sources/AllSet/Features/Widgets/Kinds/Time/ClockWidget.swift` |
| `Sources/AllSet/Widgets/Kinds/CalendarWidget.swift` | `Sources/AllSet/Features/Widgets/Kinds/Productivity/CalendarWidget.swift` |
| `Sources/AllSet/Widgets/Kinds/FocusWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Productivity/FocusWidgets.swift` |
| `Sources/AllSet/Widgets/Kinds/ProductivityWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Productivity/ProductivityWidgets.swift` |
| `Sources/AllSet/Widgets/Kinds/SystemWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/System/SystemWidgets.swift` |
| `Sources/AllSet/Widgets/Kinds/SystemMetricWidget.swift` | `Sources/AllSet/Features/Widgets/Kinds/System/SystemMetricWidget.swift` |
| `Sources/AllSet/Widgets/Kinds/DarkWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/System/DarkWidgets.swift` |
| `Sources/AllSet/Widgets/Kinds/DeveloperWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Developer/DeveloperWidgets.swift` |
| `Sources/AllSet/Widgets/Kinds/WeatherWidget.swift` | `Sources/AllSet/Features/Widgets/Kinds/Lifestyle/WeatherWidget.swift` |
| `Sources/AllSet/Widgets/Kinds/DaylightWidget.swift` | `Sources/AllSet/Features/Widgets/Kinds/Lifestyle/DaylightWidget.swift` |
| `Sources/AllSet/Widgets/Kinds/AestheticWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Lifestyle/AestheticWidgets.swift` |
| `Sources/AllSet/Widgets/Kinds/SceneWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Aesthetic/SceneWidgets.swift` |
| `Sources/AllSet/Widgets/Kinds/PolaroidsWidget.swift` | `Sources/AllSet/Features/Widgets/Kinds/Aesthetic/PolaroidsWidget.swift` |
| `Sources/AllSet/Widgets/Kinds/DecorWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Aesthetic/DecorWidgets.swift` |
| `Sources/AllSet/Widgets/Kinds/LifestyleAndAestheticWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Aesthetic/LifestyleAndAestheticWidgets.swift` |
| `Sources/AllSet/Widgets/Kinds/FootballWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Football/FootballWidgets.swift` |
| `Sources/AllSet/Widgets/Kinds/MusicWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Music/MusicWidgets.swift` |
| `Sources/AllSet/Widgets/Kinds/MysticWidgets.swift` | `Sources/AllSet/Features/Widgets/Kinds/Mystic/MysticWidgets.swift` |
| `Sources/AllSet/Widgets/Kinds/CinematicWidgetFace.swift` | `Sources/AllSet/Features/Widgets/Kinds/CinematicWidgetFace.swift` |

### Step 6-support  (19 moves)

| Current | Target |
|---|---|
| `Sources/AllSetCore/Support/StoreFile.swift` | `Sources/AllSetCore/Support/Storage/StoreFile.swift` |
| `Sources/AllSetCore/Support/DataArchive.swift` | `Sources/AllSetCore/Support/Storage/DataArchive.swift` |
| `Sources/AllSetCore/Support/FileDigest.swift` | `Sources/AllSetCore/Support/Storage/FileDigest.swift` |
| `Sources/AllSetCore/Support/KeychainItem.swift` | `Sources/AllSetCore/Support/Security/KeychainItem.swift` |
| `Sources/AllSetCore/Support/AdminGate.swift` | `Sources/AllSetCore/Support/Security/AdminGate.swift` |
| `Sources/AllSetCore/Support/ContainedPath.swift` | `Sources/AllSetCore/Support/Security/ContainedPath.swift` |
| `Sources/AllSetCore/Support/CommandRunner.swift` | `Sources/AllSetCore/Support/Concurrency/CommandRunner.swift` |
| `Sources/AllSetCore/Support/LineReader.swift` | `Sources/AllSetCore/Support/Concurrency/LineReader.swift` |
| `Sources/AllSetCore/Support/SharedRequests.swift` | `Sources/AllSetCore/Support/Concurrency/SharedRequests.swift` |
| `Sources/AllSetCore/Support/RetryBackoff.swift` | `Sources/AllSetCore/Support/Concurrency/RetryBackoff.swift` |
| `Sources/AllSetCore/Support/PerformancePolicy.swift` | `Sources/AllSetCore/Support/Performance/PerformancePolicy.swift` |
| `Sources/AllSetCore/Support/NeededTimer.swift` | `Sources/AllSetCore/Support/Performance/NeededTimer.swift` |
| `Sources/AllSetCore/Support/CostCache.swift` | `Sources/AllSetCore/Support/Performance/CostCache.swift` |
| `Sources/AllSetCore/Support/ImageCost.swift` | `Sources/AllSetCore/Support/Performance/ImageCost.swift` |
| `Sources/AllSetCore/Support/Format.swift` | `Sources/AllSetCore/Support/Text/Format.swift` |
| `Sources/AllSetCore/Support/DisplayIdentity.swift` | `Sources/AllSetCore/Support/Display/DisplayIdentity.swift` |
| `Sources/AllSetCore/Support/ScreenCoverage.swift` | `Sources/AllSetCore/Support/Display/ScreenCoverage.swift` |
| `Sources/AllSetCore/Search/SearchMatch.swift` | `Sources/AllSetCore/Support/Text/SearchMatch.swift` |
| `Sources/AllSetCore/Support/RollingSeries.swift` | `Sources/AllSetCore/System/RollingSeries.swift` |

### Step 7-screenshot  (4 moves)

| Current | Target |
|---|---|
| `Sources/AllSet/Screenshot/ScreenshotStudio.swift` | `Sources/AllSet/Features/Screenshot/ScreenshotStudioView.swift` |
| `Sources/AllSetCore/AI/ScreenshotStudio.swift` | `Sources/AllSetCore/Screenshot/ScreenshotStudio.swift` |
| `Sources/AllSetCore/AI/ScreenshotEdit.swift` | `Sources/AllSetCore/Screenshot/ScreenshotEdit.swift` |
| `Sources/AllSetCore/AI/AIImageEditors.swift` | `Sources/AllSetCore/Screenshot/AIImageEditors.swift` |

### Step 8-tests  (37 moves)

| Current | Target |
|---|---|
| `Tests/AllSetCoreTests/ClipboardTests.swift` | `Tests/AllSetCoreTests/Clipboard/ClipboardTests.swift` |
| `Tests/AllSetCoreTests/ImageImportTests.swift` | `Tests/AllSetCoreTests/Imagery/ImageImportTests.swift` |
| `Tests/AllSetCoreTests/WallpaperSearchTests.swift` | `Tests/AllSetCoreTests/Imagery/WallpaperSearchTests.swift` |
| `Tests/AllSetCoreTests/KnockTests.swift` | `Tests/AllSetCoreTests/Knock/KnockTests.swift` |
| `Tests/AllSetCoreTests/LidPlaneTests.swift` | `Tests/AllSetCoreTests/LidPlane/LidPlaneTests.swift` |
| `Tests/AllSetCoreTests/MixerTests.swift` | `Tests/AllSetCoreTests/Mixer/MixerTests.swift` |
| `Tests/AllSetCoreTests/GainBoxTests.swift` | `Tests/AllSetCoreTests/Mixer/GainBoxTests.swift` |
| `Tests/AllSetCoreTests/ScreenshotAITests.swift` | `Tests/AllSetCoreTests/Screenshot/ScreenshotAITests.swift` |
| `Tests/AllSetCoreTests/ScreenshotShortcutTests.swift` | `Tests/AllSetCoreTests/Screenshot/ScreenshotShortcutTests.swift` |
| `Tests/AllSetCoreTests/ScreenshotStudioTests.swift` | `Tests/AllSetCoreTests/Screenshot/ScreenshotStudioTests.swift` |
| `Tests/AllSetCoreTests/CommandRunnerTests.swift` | `Tests/AllSetCoreTests/Support/CommandRunnerTests.swift` |
| `Tests/AllSetCoreTests/ContainedPathTests.swift` | `Tests/AllSetCoreTests/Support/ContainedPathTests.swift` |
| `Tests/AllSetCoreTests/CostCacheTests.swift` | `Tests/AllSetCoreTests/Support/CostCacheTests.swift` |
| `Tests/AllSetCoreTests/DataArchiveTests.swift` | `Tests/AllSetCoreTests/Support/DataArchiveTests.swift` |
| `Tests/AllSetCoreTests/DisplayIdentityTests.swift` | `Tests/AllSetCoreTests/Support/DisplayIdentityTests.swift` |
| `Tests/AllSetCoreTests/KeychainItemTests.swift` | `Tests/AllSetCoreTests/Support/KeychainItemTests.swift` |
| `Tests/AllSetCoreTests/NeededTimerTests.swift` | `Tests/AllSetCoreTests/Support/NeededTimerTests.swift` |
| `Tests/AllSetCoreTests/PerformancePolicyTests.swift` | `Tests/AllSetCoreTests/Support/PerformancePolicyTests.swift` |
| `Tests/AllSetCoreTests/SearchMatchTests.swift` | `Tests/AllSetCoreTests/Support/SearchMatchTests.swift` |
| `Tests/AllSetCoreTests/BatteryHealthTests.swift` | `Tests/AllSetCoreTests/System/BatteryHealthTests.swift` |
| `Tests/AllSetCoreTests/BatteryTests.swift` | `Tests/AllSetCoreTests/System/BatteryTests.swift` |
| `Tests/AllSetCoreTests/DesktopJournalTests.swift` | `Tests/AllSetCoreTests/Themes/DesktopJournalTests.swift` |
| `Tests/AllSetCoreTests/DesktopSnapshotTests.swift` | `Tests/AllSetCoreTests/Themes/DesktopSnapshotTests.swift` |
| `Tests/AllSetCoreTests/ThemeCarouselLayoutTests.swift` | `Tests/AllSetCoreTests/Themes/ThemeCarouselLayoutTests.swift` |
| `Tests/AllSetCoreTests/ThemeLibraryTests.swift` | `Tests/AllSetCoreTests/Themes/ThemeLibraryTests.swift` |
| `Tests/AllSetCoreTests/ThemeWidgetCatalogTests.swift` | `Tests/AllSetCoreTests/Themes/ThemeWidgetCatalogTests.swift` |
| `Tests/AllSetCoreTests/FandomTests.swift` | `Tests/AllSetCoreTests/Themes/FandomTests.swift` |
| `Tests/AllSetCoreTests/WallpaperLibraryTests.swift` | `Tests/AllSetCoreTests/Wallpaper/WallpaperLibraryTests.swift` |
| `Tests/AllSetCoreTests/FocusTimerCoordinatorTests.swift` | `Tests/AllSetCoreTests/Widgets/FocusTimerCoordinatorTests.swift` |
| `Tests/AllSetCoreTests/MysticTests.swift` | `Tests/AllSetCoreTests/Widgets/MysticTests.swift` |
| `Tests/AllSetCoreTests/StudioDiscoveryTests.swift` | `Tests/AllSetCoreTests/Widgets/StudioDiscoveryTests.swift` |
| `Tests/AllSetCoreTests/WidgetGridTests.swift` | `Tests/AllSetCoreTests/Widgets/WidgetGridTests.swift` |
| `Tests/AllSetCoreTests/WidgetResizeTests.swift` | `Tests/AllSetCoreTests/Widgets/WidgetResizeTests.swift` |
| `Tests/AllSetCoreTests/WidgetPlatformTests.swift` | `Tests/AllSetCoreTests/Widgets/WidgetPlatformTests.swift` |
| `Tests/AllSetCoreTests/AestheticsV2Tests.swift` | `Tests/AllSetCoreTests/Widgets/AestheticsV2Tests.swift` |
| `Tests/AllSetCoreTests/WorkspaceTests.swift` | `Tests/AllSetCoreTests/Workspace/WorkspaceTests.swift` |
| `Tests/AllSetCoreTests/HardeningTests.swift` | `Tests/AllSetCoreTests/Support/StoreFileTests.swift` |

### Step 9-docs  (36 moves)

| Current | Target |
|---|---|
| `docs/UI-Spec.md` | `Documentation/UI-Spec.md` |
| `docs/perf-audit.md` | `Documentation/perf-audit.md` |
| `docs/wallpaper-import.md` | `Documentation/wallpaper-library/import.md` |
| `Documentation/spec.md` | `Documentation/wallpaper-library/spec.md` |
| `Documentation/architecture.md` | `Documentation/wallpaper-library/architecture.md` |
| `Documentation/report.md` | `Documentation/wallpaper-library/report.md` |
| `Documentation/operations.md` | `Documentation/wallpaper-library/operations.md` |
| `Documentation/scene-renderer-diagnosis.md` | `Documentation/wallpaper-library/scene-renderer-diagnosis.md` |
| `Documentation/audit-2026-09-29.md` | `Documentation/Reports/2026-09-29-audit.md` |
| `rules_frontend.md` | `Documentation/frontend-rules.md` |
| `CONTENT.md` | `Documentation/content.md` |
| `docs/reference/concept2-reference.png` | `Documentation/design/reference/concept2-reference.png` |
| `docs/reference/themes-scroll-target.png` | `Documentation/design/reference/themes-scroll-target.png` |
| `design/themes-concepts/2026-10-05-cinematic-reference/aurora-asset-prompt.json` | `Documentation/design/themes-concepts/2026-10-05-cinematic-reference/aurora-asset-prompt.json` |
| `design/themes-concepts/2026-10-05-cinematic-reference/prompt.json` | `Documentation/design/themes-concepts/2026-10-05-cinematic-reference/prompt.json` |
| `design/themes-concepts/2026-10-05-cinematic-reference/themes-preview.png` | `Documentation/design/themes-concepts/2026-10-05-cinematic-reference/themes-preview.png` |
| `design/themes-concepts/2026-10-05-original/01-editorial-studio.png` | `Documentation/design/themes-concepts/2026-10-05-original/01-editorial-studio.png` |
| `design/themes-concepts/2026-10-05-original/02-chromatic-lab.png` | `Documentation/design/themes-concepts/2026-10-05-original/02-chromatic-lab.png` |
| `design/themes-concepts/2026-10-05-original/03-soft-spatial.png` | `Documentation/design/themes-concepts/2026-10-05-original/03-soft-spatial.png` |
| `design/themes-concepts/2026-10-05-original/prompts.json` | `Documentation/design/themes-concepts/2026-10-05-original/prompts.json` |
| `design/themes-concepts/2026-10-05/01-cinematic-carousel.png` | `Documentation/design/themes-concepts/2026-10-05/01-cinematic-carousel.png` |
| `design/themes-concepts/2026-10-05/02-gallery-atelier.png` | `Documentation/design/themes-concepts/2026-10-05/02-gallery-atelier.png` |
| `design/themes-concepts/2026-10-05/03-immersive-desktop.png` | `Documentation/design/themes-concepts/2026-10-05/03-immersive-desktop.png` |
| `design/themes-concepts/2026-10-05/prompts.json` | `Documentation/design/themes-concepts/2026-10-05/prompts.json` |
| `design/wallpaper-concepts/2026-10-05-v2/01-cinematic-library.png` | `Documentation/design/wallpaper-concepts/2026-10-05-v2/01-cinematic-library.png` |
| `design/wallpaper-concepts/2026-10-05-v2/02-preview-studio.png` | `Documentation/design/wallpaper-concepts/2026-10-05-v2/02-preview-studio.png` |
| `design/wallpaper-concepts/2026-10-05-v2/03-immersive-cinema.png` | `Documentation/design/wallpaper-concepts/2026-10-05-v2/03-immersive-cinema.png` |
| `design/wallpaper-concepts/2026-10-05-v2/prompts.json` | `Documentation/design/wallpaper-concepts/2026-10-05-v2/prompts.json` |
| `design/wallpaper-concepts/2026-10-05/01-cinematic-discovery.png` | `Documentation/design/wallpaper-concepts/2026-10-05/01-cinematic-discovery.png` |
| `design/wallpaper-concepts/2026-10-05/02-gallery-inspector.png` | `Documentation/design/wallpaper-concepts/2026-10-05/02-gallery-inspector.png` |
| `design/wallpaper-concepts/2026-10-05/03-immersive-theater.png` | `Documentation/design/wallpaper-concepts/2026-10-05/03-immersive-theater.png` |
| `design/wallpaper-concepts/2026-10-05/prompts.json` | `Documentation/design/wallpaper-concepts/2026-10-05/prompts.json` |
| `design/wallpaper-concepts/SELECTED.md` | `Documentation/design/wallpaper-concepts/SELECTED.md` |
| `design/widgets-concepts/2026-10-05/01-widget-library.png` | `Documentation/design/widgets-concepts/2026-10-05/01-widget-library.png` |
| `design/widgets-concepts/2026-10-05/asset-manifest.json` | `Documentation/design/widgets-concepts/2026-10-05/asset-manifest.json` |
| `design/widgets-concepts/SELECTED.md` | `Documentation/design/widgets-concepts/SELECTED.md` |
