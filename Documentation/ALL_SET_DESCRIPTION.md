# All Set for Mac

All Set is a native macOS app that customises the whole Mac desktop. It combines a **Dynamic Island** on the notch, **desktop widgets**, whole-desktop **themes** and **live wallpapers** in one app.

- **Platform:** Apple Silicon only, macOS 14.2 or later, Swift 6 (AppKit + SwiftUI).
- **Distribution:** direct download, with a Developer ID and notarization planned. It is not sandboxed and is not on the Mac App Store.
- **Repo:** `nawddeep/All_Set_Mac` (git remote `final`). Development happens on `main`; the latest work is on `fix/production-readiness`.

## The four pillars

### 1. Dynamic Island
Hover over or click the notch to open a panel with Now Playing (artwork and controls), live system readings, and Notes with alarms and a stopwatch. While the panel is closed, live activities appear beside the notch: music, volume, charging, low battery and audio output changes. Macs without a notch get a virtual one in the menu bar.

### 2. Desktop widgets
There are 54 widget kinds and 91 widgets in the gallery, including:
- clocks, calendar, weather and photos;
- system stats, notes, focus timers and GitHub;
- football and music widgets: jersey, player card, scoreboard, vinyl and cassette.

How they behave:
- Each widget comes in several sizes and card styles.
- Widgets snap to a grid of 168 pt cells with 16 pt gaps.
- Arrange mode moves and resizes widgets.
- Every word in a widget can be renamed.
- Each display keeps its own layout, and widgets refit when a monitor or resolution changes.

### 3. Themes
There are 111 whole-desktop themes. Each one is a set of widgets, their look and a wallpaper, all designed together. The families are:

| Family | Count |
|---|---|
| Moodboards | 14 |
| Football & Music | 22 |
| Colour & Light | 8 |
| Core | 14 |
| Studio Originals | 25 |
| Desktop Edit | 25 |
| Monochrome Edit | 3 |

There are also 15 design themes, which restyle widgets without adding a layout.

Ways to use a theme:
- **Install modes:** Replace, Add or Restyle.
- **Preview on desktop**, with crash-safe restore if the app quits mid-preview.
- **Undo**, and **Restore Previous Desktop**, which survives a relaunch.
- **Personalise** a theme by putting your own photos in its photo slots.

The Themes page leads with a carousel hero. The selected theme is shown as a landscape desktop, with portrait neighbours beside it. The page is lit in that theme's own colours, and its rails and shelves are organised by collection.

The full design write-up is in `Documentation/HOW_THEMES_ARE_MADE.md`.

### 4. Wallpaper
There are three kinds of wallpaper:
- 36 built-in live wallpapers drawn on the Mac, with nothing to download;
- your own looping videos;
- a library folder of your own.

It pauses when the desktop is covered or locked, during sleep, in Low Power Mode or on battery. It also sets a matching still image as the system wallpaper, and your own wallpaper comes back when you turn it off. 943 generative artworks (style × palette combinations) are used by themes.

## Extras
Extras are optional and **all off on a new install**. They are switched on in Extras › Manage:
- Window Snapping
- Workspaces
- Clipboard History
- Shelf
- Sound Mixer
- TapTap (knocks)
- AI Screenshot
- System Monitor

An extra that is off starts nothing, holds no shortcut and asks for no permission.

The window has four places: **Island, Desktop, Extras and Settings** (⌘1–⌘4). ⌘K searches every page.

## Architecture
SwiftPM package with four targets:
- `AllSet`: the app (AppKit + SwiftUI views, `AppServices` with feature coordinators).
- `AllSetCore`: models, themes, widgets, stores and logic. It is unit-tested, with about 470 tests.
- `CPrivateAPIs`: bridging headers.
- `MediaHelper`: a dylib for Now Playing. It is loaded through Apple-signed `/usr/bin/perl`, because macOS 15.4+ only gives Now Playing info to Apple-signed processes. It has a 3 s deadline and at most 3 retries.

Other parts:
- **Private interfaces.** Now Playing, temperatures, the motion sensor, hot keys, Core Audio taps, symbolic hot keys and the TCC permission check all go through `Capabilities`. Each one has a kill switch (`defaults write com.pratik.allset capability.<name>.disabled -bool YES`) and a status line in Settings.
- **Data.** User data is plain files in `~/Library/Application Support/AllSet`, with backup and restore. There is no account, analytics or tracking.
- **Network.** Every host the app can contact is listed in `NetworkUse.swift` and shown in Settings, and a test keeps that list complete.
- **Permissions.** Accessibility, Calendars and Audio Recording are asked for only when a feature that needs them is turned on.
- **Updates.** Sparkle 2 with EdDSA-signed updates. Updates are off until the key exists.
- **Crash reports.** MetricKit plus Export Diagnostics; reports stay on the Mac unless exported.
- **Personal wallpaper server.** `scripts/cloud` is the owner's library server on Tailscale and is not public. SQL values are passed only as psql variables. A public HTTPS catalogue is planned.

## Rules that keep the app what it is
- **Performance first, measured.** Anything that moves all day uses Core Animation, not SwiftUI animation. There is no animated blur on scrolling content and no cross-fading of whole pages. Measure with `-probe` before and after a change; budgets are in `scripts/probe-budgets.json`.
- **Zero warnings.** No file over 600 lines.
- **Originality.** No real people, clubs, nations, crests, album art or lyrics, enforced by `RealPeopleDenylistTests`. Photos are CC0.
- **No new network host** unless it is listed in `NetworkUse.swift`.
- **Private APIs** only go through `Capabilities`.
- **Keep the Themes carousel hero.** Show big UI changes before relaunching the app.

## Build and check
| Command | What it does |
|---|---|
| `make run` | Debug app plus the Now Playing helper |
| `make test` | Unit tests |
| `./scripts/build-app.sh` | Signed release app in `build/AllSet.app` |
| `CFFIXED_USER_HOME=/tmp/h .build/debug/AllSet -smokeTest /tmp/smoke` | End-to-end walk-through on throwaway data |
| `-renderPages` | Renders pages |
| `-probe scroll\|pages\|covered\|pageswitch` | Performance probes, run on a release `-DDEBUG` build |
| `scripts/check-repo-hygiene.sh`, `scripts/check-localization.sh` | Repo and localization checks |

Anything that touches app data must run against a throwaway home, never the real one.

CI jobs: hygiene, build-and-test, smoke, minimum-os (arm64 macOS 14.2), package, screenshots, probe and server-scripts. Pushing a `v*` tag releases: it signs, notarizes, packages a dmg and zip, writes the appcast and publishes a GitHub Release.

## Current state (2026-10-18)
The production-readiness pass is finished: 37 findings addressed, 45 commits, with the report in `Documentation/PRODUCTION_READINESS_REPORT.md`.

Not ready for a public release yet. What's still open:
- **Apple Developer ID.** Without it there's no notarization; ad-hoc builds lose permissions on every update.
- **Scroll CPU.** It is 41–100% on Themes, Gallery and Wallpaper, against a 20% target.
- **Content rights** for public wallpapers.
- **Testing on real machines.** The app has never run on a real macOS 14 or 15 Mac.
- **Latest CI run on `main`.** build-and-test and probe failed (Themes idle CPU 25% against a 2.75% limit).

Owner to-dos are in `Documentation/OWNER_ACTIONS.md`, and the session handoff is in `Documentation/HANDOFF.md`.
