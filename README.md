# All Set

A coordinated desktop for the Mac, built with SwiftUI: themes, widgets and live wallpapers, with a Dynamic Island on the notch and a system monitor.

What is fixed, open or waiting on a decision is tracked in `Documentation/Reports/2026-10-06-audit-repairs.md`. Dated reports beside it are history, not current defects. The wallpaper server is described in `Documentation/operations.md`.

- **Notch hub**: hover over or click the notch to open a panel with Now Playing controls and live stats. While closed, live activities appear beside the notch: now playing, volume changes, charging, low battery, and audio output switches.
- **System monitor**: CPU per core (efficiency and performance cores shown separately), GPU, memory and pressure, network, disk space and I/O, SoC/SSD/battery temperatures, battery health, cycles and power draw.
- **Theme library**: 57 complete desktops, led by 14 photo moodboards (Leopard Noir, City Noir, Angelic, Hypnotic, After Dark, Streetwear, Gallery, Silver Faith, Peace of Mind, Cherry Night, Stardust, Soft Mono, Boho Sand, The Beginning): black-and-white photo walls, script words, sticker tiles and textured wallpapers, plus the original aesthetic setups. Browse, search, preview on the desktop, apply with undo or turn off; the Themes banner shows the theme on your desktop. Card previews are rendered pictures, cached on disk, and drawn only while you aren't scrolling.
- **Football & music worlds**: 17 more complete desktops: Seven, Galáctico, Albiceleste, O Rei, Samba Neon, Miami Pink and Matchday for football; Americana, Coastline, Velvet Noir, Rage Mode, Sad Hours, Slime Green, Deep Blue, Crimson Nights, Vamp Punk and Blond Summer for music. Original designs inspired by eras and moods fans know; they name no one and use no official photos, crests, logos, album art or lyrics. Photos are CC0 (Openverse), wallpapers are generated (new Stadium Lights, Palm Sunset and Smoke styles), and "Use My Photos…" fills every photo slot with your own pictures: kept per theme on this Mac only (theme-photos.json), with player cards lifting the player out of the photo with Vision. Twelve football worlds now, including Red Seven, Wonderkid, Bleu Royal, Milano Nights and Hall of Fame.
- **Live football and music widgets**: Shirt (your name and number, seven kit patterns), Player Card (foil rating card with your photo and stats), Tactics Board (formation with the ball in play), Scoreboard (LED board counting down to kickoff, or a final score), Milestone, Cassette (reels turn while music plays), VHS (a photo as home video, tracking lines and REC), Visualizer (bars, waveform or ring), Ticket and Word Art (chrome, gold, neon, glitter, fire, ice, holographic). Glow, float, shine, sparkle and bars run in Core Animation, so a whole desktop of them idles at about 1% CPU.
- **Design themes**: 15 design languages that draw every widget through one theme engine (`DesignTheme` + `WidgetStyle` + shared components), each in light and dark with an Automatic setting: Apple Minimal, Liquid Glass, Dark Glass, Aurora, AMOLED, Cyberpunk, Terminal, Retro Macintosh, Japanese Zen, Editorial, Brutalist, Neumorphism, Paper, Monochrome and Dynamic Wallpaper (a subtle accent taken from your desktop picture). Per widget: theme, appearance, accent, transparency and refresh behavior.
- **Widget catalog**: 91 widgets in Time, Productivity, System, Developer, Lifestyle, Aesthetic, Football, Music and Mystic, registered in `WidgetCatalog` so a new one is a view plus an entry. New this round: Minimal and World clocks, Date, Next Event, Daily Goals, Habit Tracker, Reading Progress, System metrics (CPU, Memory, Disk, Storage, Network, Wi-Fi, Battery Health, Uptime, Status), GitHub (Contributions, Activity, Pull Requests, Issues, Repository, CI/CD), API and Server Status, Air Quality, and the Classic Mac, Ensō and Magazine Cover aesthetic widgets. Weather, System Monitor and GitHub come in Extra Large too.
- **Deep links**: `allset://open/<page>` (`home`, `island`, `themes`, `gallery` or a widget category, `art`, `wallpaper`, `desktop`, `monitor`, `clipboard`, `notes`, `workspaces`, `mixer`, `settings`), `allset://widget/<id>`, `allset://arrange`, `allset://theme/<id>`, `allset://focus/start|pause|reset`, for Shortcuts, Raycast and scripts.
- **Aesthetic setups**: thirteen whole-desktop looks, filterable by dark or light: Cloud Nine, Pink Latte, Coquette (light); Good Things, Grunge, Diva, Luxe Noir, Sepia Swag, Vigilante, Neon Nights, Dark Academia, Midnight Lo-fi, Goth (dark); plus eight Colour & Light looks: Matcha Morning, Peach Fizz, Lavender Haze, Candy Pop, Ocean Glass, Sunset Drive, Forest Cabin and Desert Bloom. "Apply Look" restyles every widget (card, colors, font, corners) and sets a matching live wallpaper; "Use Full Setup" lays out the theme's own starter set of widgets, with Undo.
- **Desktop widgets**: Clock (digital, analog, stacked, words or flip, any time zone), Calendar (month and upcoming events), Weather (any city, hourly and 5-day), System, Battery, Now Playing and sticky Notes. Each comes in small, medium or large, on a Glass, Dark, Light, Color, Solid (paper), Frosted, Outline or No Card style, with your own card, text and highlight colors. Choose the font and corner roundness for all of them. Arrange mode lets you drag widgets anywhere; they snap to a grid of quarter-small-widget slots (dropping on a same-size widget swaps them), each display keeps its own widget size, and a resolution change or another monitor refits them. Removing a widget is one click, with Undo.
- **Aesthetic widgets**: Photo (your pictures, ~1,000 Unsplash photos or generated art, with filters, Polaroid, inset, collage and film strip frames, captions and slideshows), Live Scene (animated art with the time, date or your words on top), Quote (including Poster, Chunky, Editorial, Gothic and Luxe type), Neon Sign (glowing, flickering words), Countdown, Sticker (a big star, heart, sparkle or emoji: soft, glossy, chrome, die-cut or outline) and Shortcuts (cute icons that open apps and sites). Any widget can sit on one of 943 generative artworks (23 styles × 41 palettes), still or animated.
- **Focus & To-Do widgets**: To-Do (the notch's Notes as a checklist), a Pomodoro Focus Timer, a Stopwatch (running timers survive quitting the app) and Year in Dots. The System section adds a Terminal widget: live stats in green on black.
- **One main window**, opened from the Dock icon: always dark, on a deep navy backdrop with soft blue light drifting across it (Core Animation, frozen under Reduce Motion, Low Power Mode or while hidden). A floating navigation holds five places, Island, Desktop, Workspace, Tools and System (⌘1–⌘5), with each place's pages as pills beneath: the Dynamic Island page (live miniature, "Try it on your notch" buttons, every island setting), Themes, the widget Gallery, Art, Wallpaper, Look & Layout, On Your Desktop (each placed widget, to customize or remove), Window Snapping, Workspaces, Clipboard, Shelf, Sound Mixer, TapTap, AI Screenshot, Notes, a live Monitor, General and About. Wallpaper, Themes and Art open on a full-bleed hero that runs under the navigation. "Show in Dock" can switch the app back to menu-bar-only.
- **Live wallpaper**: your own wallpaper library (imported from a Wallpaper Engine folder, optionally fetched from a personal server), any of the 943 artworks animated (including Night Skyline with a searchlight, Embers, Cloud Nine, Floating Hearts, Hypnotic spiral, Leopard, Film Grain and Checkerboard), a photo with slow cinematic drift, or your own looping videos, drawn behind desktop icons. Picking a wallpaper changes only the wallpaper; your widgets stay. Undo, and Widgets › Restore Previous Desktop (which survives a relaunch), put the old one back. It pauses when covered, locked, asleep, in Low Power Mode or on battery (on by default), and sets a matching still as the system wallpaper (your original comes back when you turn it off).
- **Workspace manager**: window snapping by keyboard (Rectangle's shortcuts: ⌃⌥ arrows for halves, ⌃⌥U/I/J/K quarters, ⌃⌥D/F/G thirds, ⌃⌥↩ maximize, ⌃⌥C center, ⌃⌥⌫ restore, ⌃⌥⌘ arrows to move between displays; all re-recordable), optional gaps, drag-to-edge snapping with a preview (when macOS's own tiling is off), and saved workspaces that reopen apps and put their windows back where they were (the layout, not the documents), optionally hiding everything else, from a click, the menu bar or a shortcut. A switch says which apps or windows didn't come back.
- **Clipboard & Shelf**: clipboard history (text, links, images, files; password managers and private copies skipped), off until you turn it on, with a ⌃⌥V picker that searches and pastes into the app in front, on-device OCR for copied images, copies forgotten after a number of days you choose (pinned items stay), an option to clear history when the app quits, Erase Everything, and a Shelf where files dragged onto the notch wait until you drag them out. The notch's Tray tab shows both.
- **Your data**: everything is files in one folder on this Mac. General › Back up and restore exports it to a folder with checksums and restores from one, keeping what it replaces. API keys stay in the Keychain and are never exported.
- **Photo search** in the photo picker (for Photo and other picture widgets) across Creative Commons photos (Openverse), alongside ~1,000 featured Unsplash photos. It understands aesthetics ("coquette", "dark academia", "lo-fi" become concrete searches that pages take turns through), fixes typos, shows matching built-in art instantly, paces requests under Openverse's limit, and falls back to cached results when offline.
- **Menu bar panel** with the same stats.

On screens without a notch, All Set draws a virtual one in the menu bar.

## Requirements
- macOS 14.2 or later (developed on macOS 26, Apple Silicon)
- Xcode, for the Swift 6 toolchain and SDK
- VS Code with the **Swift** extension (`swiftlang.swift-vscode`)

## Commands
| Command                  | What it does                                                    |
|--------------------------|-----------------------------------------------------------------|
| `make run`               | Build and run the debug app                                     |
| `make preview TAB=home`  | Run with the notch panel held open (`home`, `tray` or `system`) |
| `make test`              | Run the tests                                                   |
| `make open`              | Build `build/AllSet.app` (release) and open it                  |
| `make clean`             | Remove build output                                             |
| `./scripts/setup-signing.sh` | One time: creates a local signing certificate so macOS remembers Accessibility permission across rebuilds |
| `scripts/check-repo-hygiene.sh` | Fails if build output, `*.env` files or files over 5 MB are tracked (CI runs it) |

## CI and releases
- **CI** (`.github/workflows/ci.yml`) runs on every push to `main` and every pull request: repository hygiene, a zero-warning build and the tests, the release app packaged exactly as a release is (zip and DMG, mounted and signature-checked), page screenshots, CPU and smoothness budgets, and the server scripts against a throwaway Postgres.
- **Releases** (`.github/workflows/release.yml`): `git tag v1.2.0 && git push origin v1.2.0` tests, builds, packages and publishes a GitHub Release with `AllSet-1.2.0.dmg`, `AllSet-1.2.0.zip` and `SHA256SUMS.txt`. A tag like `v1.2.0-beta.1` is a pre-release. Without signing secrets the app is signed ad hoc and the release notes tell people how to open it the first time; add the Developer ID and notarization secrets listed at the top of `release.yml` to sign and notarize.
- To package locally the same way: `ALLSET_APP_DIR=$PWD/dist/AllSet.app scripts/build-app.sh && scripts/package-release.sh dist/AllSet.app dist 1.2.0`.

In VS Code, **F5** builds and debugs the app, and the *Debug AllSet (notch open)* launch configuration holds the panel open. **Cmd+Shift+B** builds. Other commands are under *Terminal → Run Task*.

`.build/debug/AllSet -renderDesign /folder` captures every design theme in light and dark, and every catalog entry at every size, from real (hidden) windows, so glass draws as it does on the desktop.

While developing, `.build/debug/AllSet -widgetsFile /tmp/layout.json` tries a widget layout without touching your real one, and `-arrangeWidgets YES` starts in arrange mode, and `-openPage island|themes|gallery|art|wallpaper|widget|workspaces|snapping|clipboard|mixer|knocks|notes|monitor` opens the window on a page.

`-renderPages /folder` captures every main-window page at 900×600, 1280×800 and 1728×1080, and `-probe scroll|pages|galleryparts` prints scroll smoothness and CPU. CI (`.github/workflows/ci.yml`) runs on every push: a build that fails on any warning, the tests, the page screenshots (published to the `ci-screenshots` branch) and the probes (in the run summary). The full list of debug tools is in `Documentation/HANDOFF.md`.

Use `make run` rather than `swift run`: `swift run` builds only the app, not the media helper it loads.

## Layout
```
Sources/
  AllSet/              The app: notch panel, menu bar, settings (SwiftUI + AppKit)
    Notch/             NotchController (window, hover, activities) and its views
    Widgets/           DesktopWidgetController (one desktop-level window per widget), widget views, ArtView
    Studio/            Widget gallery, library pages, widget customizer
    Wallpaper/         WallpaperController (desktop-level window per screen) and wallpaper pages
    Workspace/         Accessibility wrappers, hot keys, WindowManager, WorkspaceController, pages
    Clipboard/         ClipboardMonitor, the ⌃⌥V picker, OCR, Clipboard and Shelf pages
    Design/            Design tokens, shared components, the window backdrop and the floating navigation
    MainWindow.swift   The main window: its pages, under the floating navigation
  AllSetCore/          Everything testable without UI
    System/            CPU, GPU, memory, network, disk, battery, temperature readers
    Media/             Now Playing: MediaController and the helper protocol
    Widgets/           Widget models, themes (WidgetTheme), timers, layout math, and WidgetStore (saved to
                       ~/Library/Application Support/AllSet/widgets.json)
    Weather/ Calendar/ Open-Meteo client and EventKit events for widgets
    Aesthetics/        Art styles and palettes, photo sources, ImageLibrary, PhotoSearch (Openverse)
    Search/            SearchMatch (fuzzy names) and AestheticSearch (aesthetic vocabulary, typos, pacing)
    Wallpaper/         WallpaperStore: live wallpaper settings and imported videos
    Workspace/         Window layout math, snap zones, shortcuts, WorkspaceStore
    Clipboard/         ClipboardStore (history) and ShelfStore
    Audio/ Power/      Volume/output device and power source monitors
  MediaHelper/         Objective-C helper that /usr/bin/perl loads (see below)
  CPrivateAPIs/        Declarations for private IOKit HID functions (temperatures)
Tests/AllSetCoreTests  Unit tests, plus live checks against this Mac and the helper
Resources/              Info.plist and AppIcon.icns (redraw it with `swift scripts/make-icon.swift`)
scripts/build-app.sh   Packages the release build into build/AllSet.app
Documentation/         HANDOFF (how things work, debug tools), spec/architecture/report (wallpaper library), dated reports
```

## How the tricky parts work
- **Now Playing.** macOS 15.4 and later only give Now Playing info to Apple-signed processes. `MediaController` starts `/usr/bin/perl`, which is Apple-signed, with a short loader script. The script loads `libAllSetMediaHelper.dylib`, which reads MediaRemote and sends JSON lines back over stdout. Commands such as play/pause and seek go the other way over stdin. This is the same workaround other notch and music apps use, and a future macOS update could close it.
- **Temperatures** come from the IOKit HID event system through a few exported but undeclared functions (`CPrivateAPIs`), as in [Stats](https://github.com/exelban/stats).
- **The notch window** is a borderless, non-activating panel placed just above the menu bar. It only accepts mouse clicks while the pointer is over the shape. Everywhere else, clicks go through to the status items next to the notch.

Because of these, All Set can't be sandboxed and won't pass Mac App Store review. It's meant to be distributed directly, signed with Developer ID and notarized. Local builds are signed with the self-signed "All Set Development" certificate from `scripts/setup-signing.sh` (ad hoc if it's missing).

Weather data by [Open-Meteo.com](https://open-meteo.com) (CC BY 4.0). Photos by Unsplash photographers, served by [Picsum](https://picsum.photos); search by [Openverse](https://openverse.org).
