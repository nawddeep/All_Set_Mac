# Working on All Set

## Build and run
Needs Xcode (Swift 6 toolchain, macOS 26 SDK) on an Apple Silicon Mac.

| Command | What it does |
|---|---|
| `make run` | Build and run the debug app (use this, not `swift run`: it also builds the Now Playing helper) |
| `make preview TAB=home` | Run with the notch panel held open (`home`, `tray`, `mixer` or `system`) |
| `make test` / `swift test` | The unit tests (AllSetCore), about 470 |
| `./scripts/build-app.sh` | Release build packaged as `build/AllSet.app`, signed with the hardened runtime |
| `./scripts/setup-signing.sh` | Once: a local signing certificate, so macOS remembers permissions across rebuilds |
| `scripts/check-repo-hygiene.sh` | Fails on tracked build output, secrets, personal paths, big files (CI runs it) |
| `scripts/check-localization.sh` | Fails on alert/button/menu/toast text that isn't `String(localized:)` (CI runs it) |
| `UPDATE_COUNTS=1 swift test --filter ContentCountsTests` | Rewrites the numbers in README.md and CONTENT.md from the code |

Run anything that touches app data against a throwaway home, never your own:

```sh
mkdir -p /tmp/allset-home
CFFIXED_USER_HOME=/tmp/allset-home .build/debug/AllSet -renderPages /tmp/pages -pages themes,wallpaper
```

## Checks
- **Tests:** `swift test`. Suites tagged `.hardware` read this Mac's sensors; CI skips them by name.
- **Smoke test:** the app walked through end to end on throwaway data:
  `CFFIXED_USER_HOME=/tmp/h .build/debug/AllSet -smokeTest /tmp/smoke -skip wallpaper,widgets,notch` (refuses to run without `CFFIXED_USER_HOME`).
- **Probes** (optimised build with the debug tools): `swift build -c release -Xswiftc -DDEBUG --build-path .build-probe`, then `.build-probe/release/AllSet -probe scroll|pages|galleryparts|covered|pageswitch -skip window,wallpaper,widgets,notch`. Budgets are in `scripts/probe-budgets.json`; CI fails past them. Compare A/B builds interleaved: the Mac's load swings the numbers.
- **Renders:** `-renderPages`, `-renderOnboarding`, `-renderEntries` and the rest are listed in `Documentation/HANDOFF.md`.
- **Server scripts:** `/opt/homebrew/bin/python3 -m unittest scripts/cloud/test_*.py` (a throwaway Postgres; Postgres-backed tests skip without `postgresql@17`).

## Rules that keep the app what it is
- **Performance first, measured.** Anything that moves all day uses Core Animation, not SwiftUI animation; no cross-fading whole pages; no animated blur or glass on scrolling content. Measure with the probes before and after.
- **Zero warnings.** CI fails on any.
- **Themes are original.** No real person, club, nation, logo, album art or lyric, in what's shown or in search tags; `RealPeopleDenylistTests` scans data and source.
- **No new network host without listing it** in `NetworkUse.swift`; `NetworkUseTests` fails otherwise.
- **Private macOS interfaces go through `Capabilities`** with a kill switch.
- **A new widget kind:** a `WidgetKind` case, its definition file in `Sources/AllSetCore/Widgets/Kinds/` plus a line in `WidgetKindDefinition.all`, its view in `WidgetHostView`, and its editor section and looks (see `Documentation/HANDOFF.md`).
- **No file over 600 lines.**

## Releasing
1. Update `CHANGELOG.md` (move Unreleased under the new version).
2. `git tag v1.2.0 && git push <remote> v1.2.0`. The Release workflow tests, builds, signs (Developer ID when the secrets exist), notarizes with `scripts/notarize.sh`, packages the dmg and zip, writes the Sparkle appcast when its key exists, and publishes a GitHub Release.
3. Run `Documentation/RELEASE_CHECKLIST.md` on the published build.

To package locally the same way: `ALLSET_APP_DIR=$PWD/dist/AllSet.app scripts/build-app.sh && scripts/package-release.sh dist/AllSet.app dist 1.2.0`.
