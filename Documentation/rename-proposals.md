# Rename and split proposals (later change)

_Written 2026-10-14 alongside [restructure-plan.md](restructure-plan.md). **Nothing here is done in the file-layout change**, which only moves files. Each item below changes Swift source, so it gets its own change, build and test run._

## 1. Types named "Theme" that aren't themes

In the app, a *theme* is a `ThemeSet`: what the Themes page offers. Four other types use the word for something else. The table in `restructure-plan.md` describes what each one is.

| Today | Proposed | Why | Size of change |
|---|---|---|---|
| `Theme` (enum, `AllSet/Design/Tokens/Theme.swift`) | `AppPalette` | It's static colours for the notch, menu bar, notes and widget styles. It has nothing to do with theme sets. | 22 files in `AllSet` |
| `ThemeManager` (`AllSet/Design/Widget/WidgetStyle.swift`) | `WallpaperAccentMonitor` | It watches the desktop picture's colour (`wallpaperAccent`) and manages no themes. | 2 files |
| `WidgetTheme` + `Kit`, `KitItem` (`AllSetCore/Themes/WidgetTheme*.swift`) | `DesktopSetup` (keep `Kit`, `KitItem`) | `ThemeSet.Look.setup(_:)` already calls these "setups". The name `WidgetTheme` reads like `DesignTheme`'s twin. | `public`; about 15 files plus tests |
| `DesignTheme` and its parts `ThemePalette`, `ThemeTypography`, `ThemeWeight`, `ThemeShadow` (`AllSetCore/Widgets/DesignTheme.swift`) | `WidgetDesign`, `DesignPalette`, `DesignTypography`, `DesignWeight`, `DesignShadow` | It's how widgets are drawn, not a theme. The parts drop "Theme" to match. | `public`; about 13 files plus tests |
| `ThemeSet` | Keep | It is the theme. | — |

Before renaming any `public` Core type:
- Check that persisted data keys on raw values or ids, never on type names. `ThemeWeight: String, Codable` keeps its raw values, so saved data is unaffected.
- Check that no `-renderPages` file name is derived from a type name.

## 2. Other naming collisions

| Today | Proposed | Why |
|---|---|---|
| `SendableImage` in `AllSet/Design/Motion/LiveLayers.swift` (and in `AllSetCore/Screenshot/AIImageEditors.swift`) | Rename the app's copy, e.g. `LayerImage` | The same name in both targets: inside the app, the local one shadows Core's. |
| `LidPlane/EffectDefaults.swift` (declares `LidPlaneDefaults`) | File → `LidPlaneDefaults.swift` | A file rename only. It was left out of the layout change because it isn't on that change's problem list. |

## 3. Split the mixed widget files: one widget kind per file

These files hold widgets from more than one `WidgetKind.category`. The layout change places each whole file by majority; splitting puts every widget in its own category folder. The pieces are moved as they are, but this edits file contents, which is why it's separate from the layout change.

| File (folder after layout change) | Move out to its own file |
|---|---|
| `Productivity/FocusWidgets` | `StopwatchWidget` → `Time/` (shares `TickingText`; decide where that lives first) |
| `Productivity/ProductivityWidgets` | `DateWidget` → `Time/`; `ReadingWidget` + `BookCover` → `Lifestyle/` |
| `System/SystemWidgets` | `NowPlayingWidget` + `SampleTrack` → `Lifestyle/` (or `Music/`); `NoteWidget` → `Productivity/` |
| `System/DarkWidgets` | `DotsWidget` + `DotGrid` → `Time/`; `NeonSignWidget` → `Aesthetic/`; `TerminalWidget` stays |
| `Lifestyle/AestheticWidgets` | `AmbientWidget` → `Aesthetic/`; `CountdownWidget` → `Time/`; `QuoteWidget` own file; `PhotoWidget` stays |
| `Aesthetic/SceneWidgets` | `MoonWidget` + `NightSky`, `Starfield`, `MoonDisc` → `Lifestyle/` |
| `Aesthetic/DecorWidgets` | `ShortcutsWidget` + `ShortcutButton`, `ShortcutLauncher` → `Productivity/` |
| `Aesthetic/LifestyleAndAestheticWidgets` | `AirQualityWidget` + `AQIScale` → `Lifestyle/`; then rename what's left (Retro Window, Enso, Magazine) |
| `Music/MusicWidgets` | `WordArtWidget` + `WordArtText`, `GlitterTexture` → `Aesthetic/` |
| `Mystic/MysticWidgets` | `SpiralWidget`, `CharmWidget`, `LabelWidget` and their helpers → `Aesthetic/` |

Shared helpers used by more than one widget (for example `Typeface`, `TickingText` and the `Color` extensions) should go in `Kinds/Shared/`, not be duplicated.

## 4. Split the mixed test files

Each of these files stays at the root of `Tests/AllSetCoreTests/` in the layout change, because no single area covers half its lines. Splitting moves each suite next to what it tests. The total test count must stay 432.

| File | Suites → folder |
|---|---|
| `LogicTests` | `FormatTests`, `LineReaderTests` → Support · `RollingSeriesTests`, `CPUMathTests`, `MemoryMathTests`, `BatteryMathTests`, `ProcessGroupingTests`, `TemperatureSensorTests` → System · `NotchGeometryTests` → Notch · `NowPlayingInfoTests` → Media · `PowerEventTests` → Power · `AppSettingsTests` → Settings |
| `NotesAndPDFTests` | `NotesTests` → Notes · `PDFMakerTests` → Clipboard · `MemoryAppsTests` → System |
| `ThemesAndSearchTests` | `TimerTests` → Widgets · `AestheticSearchTests` → Imagery · `ThemeTests`, `DarkThemeTests` → Themes |
| `WidgetTests` | `WidgetStoreTests`, `WidgetLayoutTests` → Widgets · `WeatherTests` → Weather · `CalendarLayoutTests` → Calendar · `AestheticsTests` → Imagery · `SearchAndWallpaperTests` → Wallpaper |
| `WidgetNetworkTests` | Weather and GitHub request sharing and backoff: split by service, Weather / Developer |

Files already placed by majority still hold a few suites from other areas:
- `Widgets/AestheticsV2Tests` holds `PhotoSearchQualityTests` and `ImageSizingTests`, which belong in Imagery.
- `Themes/FandomTests` holds `ScreenCoverageTests` (Support), `CalmReadingsTests` (System) and `FitToScreenTests` (Settings).
- `Widgets/WidgetPlatformTests` holds `DeveloperDataTests` (Developer) and `DeepLinkTests` (Support).
- `Support/SearchMatchTests` holds `StableOrderTests` (System).
- `System/BatteryTests` holds `WallpaperBatteryDefaultTests` (Support, `PerformancePolicy`).
- `Themes/DesktopSnapshotTests` holds `WidgetStoreInsertTests` (Widgets).

`LiveSystemTests` can only move into a subfolder if its `#filePath` lookup (line 49) changes to find the package root some other way. Otherwise the test silently disables itself.
