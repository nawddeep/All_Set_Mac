# Changelog

All notable changes to All Set. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [Semantic Versioning](https://semver.org/). The build number inside the app is the commit count.

## [Unreleased]

### Added
- 36 built-in live wallpapers (generative art in five moods), first on the Wallpaper page, so a new install has plenty to pick from.
- Extras: Window Snapping, Workspaces, Clipboard History, Shelf, Sound Mixer, TapTap, AI Screenshot and System Monitor each have an on/off switch. Off, an extra starts nothing and asks for nothing.
- First-run welcome (four short steps) for new installs.
- Settings › General › Permissions: each permission that matters, its status, what it's for and what breaks without it.
- Settings › General › Network use: every connection the app can make, when, and what it sends.
- Settings › General › Restore macOS settings, and Uninstall All Set…; `scripts/uninstall.sh` for an app deleted while running.
- Asks before the first screenshot is sent to Anthropic or OpenAI.
- Deep links that change the desktop show Undo, run at most once every 2 s, and ask first when All Set isn't in front.
- Updates through Sparkle 2 (EdDSA-signed appcast), switched off until the project's update key is set.
- On-device crash and hang reports (MetricKit) and About › Export Diagnostics…; nothing is sent automatically.
- Version and build number on the About page.
- `LICENSE` (proprietary) with third-party notices; bundled photo attributions in Notices.

### Changed
- Football and music themes renamed and rewritten around invented players, clubs and fixtures; no real person, club or nation is named anywhere, including search tags. Saved desktops using the old theme ids still load.
- Photo search uses Openverse only and offers only CC0, Public Domain, CC BY and CC BY-SA photos, each credited.
- The 150 theme photos ship inside the app (each checked as CC0) instead of loading from third-party sites.
- The AI screenshot shortcut defaults to ⌃⌥⌘5, which takes nothing from macOS; taking over ⌘⇧5 asks first.
- TapTap is off by default for new installs.
- Navigation: Island, Desktop, Extras, Settings (⌘1–⌘4).
- Every build runs with the hardened runtime and only the entitlements it needs (calendars, audio input).
- Release notes and README give the macOS 15+ "Open Anyway" path for unsigned builds.

### Removed
- Lid Plane (GPL-3.0 code that would have made the whole app GPL).
- Wallhaven search.
- TapTap "Shell Command" actions (old ones load as empty slots, with a notice).
- The "Clear Cache" button that ran `sudo purge`.
- Wallpaper Engine import tooling (moved out of the product).

## [0.1.0] - 2026-10-09
- First packaged build: Dynamic Island, desktop widgets, themes, live wallpaper, workspace tools.
