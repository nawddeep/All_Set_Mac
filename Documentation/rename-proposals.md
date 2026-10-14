# Rename and split proposals (later change)

_Written 2026-10-14, revised 2026-10-15, alongside [restructure-plan.md](restructure-plan.md). **Nothing here is done in the file-layout change**, which only moves files. Each item below changes Swift source, so it gets its own change, build and test run._

## 1. Types named "Theme" that aren't themes

45 non-test types have "Theme" in the name, covering five concepts (C1 to C5 in `restructure-plan.md`, section 4). In the app, a *theme* is a `ThemeSet` (C4), what the Themes page offers. Its 36 types read correctly and stay. The other four concepts use the word for something else.

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

## 3. Split the mixed widget files: one widget per file

Ten widget files hold widgets that do different jobs. The layout change places each whole file in the folder of its biggest job (`restructure-plan.md`, section 5). Splitting puts every widget in the folder for what it does. The pieces are moved as they are, but this edits file contents, which is why it's separate from the layout change.

| File (folder after layout change) | Move out to its own file | Why |
|---|---|---|
| `Focus/FocusWidgets` | `StopwatchWidget` → `Time/` | It times, rather than plans. It shares `TickingText`, so decide where that lives first. |
| `Focus/ProductivityWidgets` | `DateWidget` → `Time/`; `NextEventWidget` → `Calendar/` | "Today, big" is a date; "what's next" is an event. Check whether `openCalendarApp` is shared with `CalendarWidget` before moving it. |
| `System/SystemWidgets` | `NowPlayingWidget` + `SampleTrack` → `Music/`; `NoteWidget` → `Focus/` | Neither reads the Mac's system state. |
| `System/DarkWidgets` | `DotsWidget` + `DotGrid` → `Time/`; `NeonSignWidget` → `Decor/`; `TerminalWidget` stays | "Every day as a dot" is a calendar of days; the neon sign is decoration. |
| `Time/LifestyleAndAestheticWidgets` | `AirQualityWidget` + `AQIScale` → `Weather/`; then name the rest after what they are (Retro Window, Enso, Magazine) | Air quality is a weather reading. |
| `Decor/AestheticWidgets` | `CountdownWidget` → `Time/`; `PhotoWidget`, `QuoteWidget`, `AmbientWidget` each in its own file | A countdown is time. The other three are separate widgets that share one file. |
| `Decor/DecorWidgets` | `ShortcutsWidget` + `ShortcutButton`, `ShortcutLauncher` → `Focus/` | An app/site launcher, not decoration. |
| `Decor/SceneWidgets` | `VinylWidget` + `Record` → `Music/`; `MoonWidget` + `NightSky`, `Starfield`, `MoonDisc` → `Weather/` | "Spins while music plays"; "tonight's moon". |
| `Music/MusicWidgets` | `VHSWidget` + `Scanlines`, `WordArtWidget` + `WordArtText`, `GlitterTexture` → `Decor/` | Neither plays or shows music. |
| `Decor/MysticWidgets` | One file per widget, in `Decor/` (or a `Decor/Mystic/` subfolder) | Eight widgets in 1,030 lines. |

Shared helpers used by more than one widget (for example `Typeface`, `TickingText` and the `Color` extensions) should go in `Kinds/Shared/`, not be duplicated.

Once split, the genre file names (`AestheticWidgets`, `DarkWidgets`, `DecorWidgets`, `LifestyleAndAestheticWidgets`, `MysticWidgets`) disappear, because each new file is named after its widget.

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
