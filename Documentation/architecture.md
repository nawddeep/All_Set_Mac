# All Set: architecture map

_Last updated: 2026-10-15, after the file-layout restructure ([restructure-plan.md](restructure-plan.md)). This is a map of where code lives and why. How the individual parts work is in [HANDOFF.md](HANDOFF.md). The wallpaper library has its own design record in [wallpaper-library/](wallpaper-library/)._

## Targets

`Package.swift` defines four targets. A file belongs to the target whose folder it sits in. Inside a target, folders are only for people: moving a file between folders of the same target changes nothing that compiles.

| Target | Folder | What it is |
|---|---|---|
| `AllSet` | `Sources/AllSet/` | The app: SwiftUI and AppKit views, windows and controllers. |
| `AllSetCore` | `Sources/AllSetCore/` | Models, stores, system readers and services, with no UI, so they can be tested. Resources: `Resources/ThemeArt` (loaded through `Bundle.module`). |
| `CPrivateAPIs` | `Sources/CPrivateAPIs/` | C declarations for private IOKit HID functions (temperatures). |
| `MediaHelper` | `Sources/MediaHelper/` | Objective-C dylib that `/usr/bin/perl` loads to read Now Playing. It isn't linked into the app. |
| `AllSetCoreTests` | `Tests/AllSetCoreTests/` | Swift Testing suites for `AllSetCore`. |

The app depends on Core; Core never depends on the app. Moving a type between the two targets is a real change (access modifiers, imports), not a move.

## `Sources/AllSet` (the app)

| Folder | What goes here |
|---|---|
| `App/` | The shell: `AllSetApp`, `AppDelegate` (launch flags such as `-renderPages`), `AppServices` (the service locator every feature reads) and its `+Themes` extension, `MainWindow` (pages), `AppNavigation` (sections and pills), `SearchOverlay` (⌘K and toasts), `MenuBar/`. |
| `Design/Tokens/` | `DS` (spacing, radii, ink and surface tokens) and `Theme` (fixed colours for the notch, menu bar and widget styles). |
| `Design/Motion/` | `Motion`, the app's animation vocabulary, and the Core Animation movers (`DriftingImage`, `LiveLayers`) that keep all-day motion off the main thread. |
| `Design/Components/` | Shared views and button styles: page scaffolds, cards, rails, chips, gauges, cinema components. |
| `Design/Backdrop/` | Window and page backdrops: `WindowBackdrop`, `StudioAtmosphere`. |
| `Design/Widget/` | How every widget is styled: `WidgetStyle` (resolved from a `DesignTheme`), widget components, `DesignSurface`, `WidgetWord`. |
| `Features/<Name>/` | One folder per feature, holding its pages, views and controllers: `Clipboard`, `Knock` (TapTap), `LidPlane`, `Mixer`, `Notch` (the Dynamic Island), `Notes`, `Screenshot`, `Settings`, `Themes`, `Wallpaper`, `Widgets`, `Workspace`. |
| `Features/Widgets/` | Desktop widget hosting: `DesktopWidgetController`, `WidgetHostView` (the kind → view switch), `WidgetWindow`, the grid overlay, backgrounds and generative art (`ArtView`, `ArtShader`). |
| `Features/Widgets/Studio/` | The Widgets gallery (`GalleryPage`), the widget customizer (`WidgetOptionsEditor`), previews, and the Art/Photos/My Photos picker (`LibraryPages`). |
| `Features/Widgets/Kinds/<Job>/` | One view per widget kind, grouped by what the widget does: `Time`, `Calendar`, `Focus`, `System`, `Weather`, `Developer`, `Music`, `Sports`, `Decor`. `CinematicWidgetFace` (an alternative face for several kinds) sits at the `Kinds/` root. Some files still hold several widgets; [rename-proposals.md](rename-proposals.md) lists the splits. |
| `Debug/` | `#if DEBUG` harnesses only: `WidgetRenderHarness` (`-renderPages`, `-renderDesign` and other captures), `PageCPUProbe` and `CarouselProbe` (`-probe`). CI runs both. |

## `Sources/AllSetCore` (logic, no UI)

A feature's logic lives in the Core folder with the **same name** as its folder in `Features/`: `Clipboard`, `Knock`, `LidPlane`, `Mixer`, `Notch`, `Notes`, `Screenshot`, `Settings`, `Themes`, `Wallpaper`, `Widgets`, `Workspace`. The other Core folders serve several features:

| Folder | What goes here |
|---|---|
| `System/` | CPU, GPU, memory, network, disk, battery, temperature and Wi-Fi readers, `SystemMonitor`, `RollingSeries`. |
| `Media/` | Now Playing: `MediaController` and the helper protocol. |
| `Calendar/`, `Weather/`, `Developer/`, `Power/` | Data sources the widgets and notch read (EventKit, Open-Meteo, GitHub and status checks, power source). |
| `Imagery/` | The shared picture layer: `ImageLibrary`, art pieces and palettes, curated and licensed photos, `PhotoSearch`, Wallhaven, `AestheticSearch`, `WallpaperColor`. Used by widgets, themes and wallpaper. |
| `Support/Storage/` | `StoreFile` (safe JSON stores), `DataArchive` (export and restore), `FileDigest`. |
| `Support/Security/` | `KeychainItem`, `AdminGate` (Touch ID for the one destructive server action), `ContainedPath`. Feature-specific keychain wrappers (`GitHubKeychain`, `AIKeychain`, `DeleteAPIKeychain`) live with their features and use `KeychainItem`. |
| `Support/Concurrency/` | `CommandRunner`, `LineReader`, `SharedRequests`, `RetryBackoff`. |
| `Support/Performance/` | `PerformancePolicy` (one place that decides how hard the app may work), `NeededTimer`, `CostCache`, `ImageCost`. |
| `Support/Text/`, `Support/Display/` | `Format`, `SearchMatch`; `DisplayIdentity`, `ScreenCoverage`. |
| `Support/DeepLink.swift` | The `allset://` URL scheme. |

### Four things called "Theme"

- **`ThemeSet`** (`Themes/`) is what the Themes page offers: a whole desktop.
- **`DesignTheme`** (`Widgets/`) is how widgets are drawn.
- **`WidgetTheme`** (`Themes/`) is an original desktop setup that a `ThemeSet` can wrap.
- **`Theme`** (`AllSet/Design/Tokens/`) is a set of fixed UI colours.

A fifth type, `ThemeManager`, watches the wallpaper's colour. [rename-proposals.md](rename-proposals.md) has the proposed clearer names.

## `Tests/AllSetCoreTests`

Test folders mirror the Core folders: `Clipboard`, `Imagery`, `Knock`, `LidPlane`, `Mixer`, `Screenshot`, `Support`, `System`, `Themes`, `Wallpaper`, `Widgets`, `Workspace`.

Seven files stay at the root:
- `TestEnvironment.swift`, a shared helper.
- `LiveSystemTests.swift`, which must stay because it finds the repo root by walking up three folders from `#filePath`. One level deeper, its helper test would silently skip.
- Five files that test several areas: `LogicTests`, `NotesAndPDFTests`, `ThemesAndSearchTests`, `WidgetNetworkTests`, `WidgetTests`.

## Everything else

| Path | What it is |
|---|---|
| `Resources/` | `Info.plist` and the app icon, copied by `scripts/build-app.sh`. |
| `scripts/` | Build, packaging, release, repo-hygiene and probe-budget scripts, plus the wallpaper importer and server scripts (`scripts/cloud/`). CI calls these paths directly, so they don't move. |
| `Documentation/` | See [README.md](README.md). `third-party/` is copied into the app bundle by `build-app.sh`. |

## Where to put new code

- A new screen or controller for an existing feature goes in `Features/<Feature>/`. Its testable logic goes in `AllSetCore/<Feature>/`, with tests in `Tests/AllSetCoreTests/<Feature>/`.
- A new widget kind goes in `Features/Widgets/Kinds/<Job>/<Name>Widget.swift`, one widget per file. Its model goes in `AllSetCore/Widgets/`.
- A view or style used by two or more features goes in `Design/`.
- Debug-only tooling goes in `Debug/`, wrapped in `#if DEBUG`.
