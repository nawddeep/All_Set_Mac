# Production readiness: progress

Branch `fix/production-readiness`, cut from `4cbf666` plus snapshot commit `5e7f5ee` (the 92 uncommitted files from earlier sessions, committed as-is at the owner's request, 2026-10-17).

Owner's choices for this run (2026-10-17): snapshot first; remove Lid Plane and rename the football/music themes; fully autonomous, local commits, no push.

On a context reset: re-read the mission prompt (in the conversation), `HANDOFF.md`, this file; resume at the first `[ ]`.

**Current phase:** 9

## Baseline (2026-10-17, before any change)
| Check | Result |
|---|---|
| `swift build` warnings | 0 |
| `swift test` | 456 tests in 105 suites, all pass |
| Swift files / lines in `Sources` | 279 files (incl. tests) / 59,596 lines in Sources |
| `try?` in Sources | 504 |
| Largest file | `WidgetOptionsEditor.swift` 1,666 lines |
| probes | see below |

## Checklist
### Phase 1: legal and licensing
- [x] T1.1 Remove Lid Plane (GPL)
- [x] T1.2 LICENSE + third-party notices
- [x] T1.3 Real people and trade dress out of themes; denylist test
- [x] T1.4 Wallhaven out; Openverse licence filter + credit; hotlinks out; Picsum credit
- [x] T1.5 Wallpaper Engine tooling moved to ../AllSet-personal

### Phase 2: product works for a stranger
- [x] T2.1 Built-in wallpapers section, never empty
- [x] T2.2 Extras section, off by default for new installs

### Phase 3: security and trust
- [x] T3.1 Knock shell command removed; knocks off by default
- [x] T3.2 purge button removed
- [x] T3.3 Honest privacy, network-use registry + test, AI send notice
- [x] T3.4 Screenshot shortcut opt-in; restore settings; uninstall
- [x] T3.5 Deep link confirmation and rate limit
- [x] T3.6 Onboarding and permission rows
- [x] T3.7 Stored action validation

### Phase 4: distribution
- [x] T4.1 Entitlements, hardened runtime for every identity
- [x] T4.2 Notarization script + workflow
- [x] T4.3 Gatekeeper instructions
- [x] T4.4 Sparkle (disabled while key is a placeholder)
- [x] T4.5 MetricKit + export diagnostics; print -> Logger
- [x] T4.6 Version in About; CHANGELOG

### Phase 5: server
- [x] T5.1 No SQL interpolation
- [x] T5.2 Catalog cache + pagination order
- [x] T5.3 Truth in docs
- [x] T5.4 Public backend plan document
- [x] T5.5 Portable server tests

### Phase 6: platform fragility
- [x] T6.1 Capabilities layer
- [x] T6.2 Minimum OS; Apple Silicon only

### Phase 7: performance
- [blocked] T7.1 Theme previews off the main thread
- [x] T7.2 Gallery cards as stills
- [x] T7.3 Pointer poll only in Arrange mode
- [x] T7.4 Seconds clock on Core Animation
- [x] T7.5 Timer audit
- [x] T7.6 CI probes on optimised build

### Phase 8: architecture
- [x] T8.1 Split AppServices
- [x] T8.2 (core only; app side open, see DECISIONS) Self-registering widget kinds
- [x] T8.3 No file over 600 lines
- [x] T8.4 (file ops; ~197 other try? not individually reviewed) try? audit
- [x] T8.5 (TSan run blocked) Concurrency
- [x] T8.6 Localization scaffolding
- [x] T8.7 Dead code

### Phase 9: testing
- [ ] T9.1 Logic into AllSetCore
- [ ] T9.2 Smoke test harness
- [ ] T9.3 De-flake
- [ ] T9.4 Release checklist
- [ ] T9.5 Accessibility

### Phase 10: repo hygiene
- [ ] T10.1 AI artefacts out
- [ ] T10.2 One docs tree; no personal paths
- [ ] T10.3 Counts from code
- [ ] T10.4 gitignore, hygiene script, CONTRIBUTING, SECURITY
- [ ] T10.5 228-file restructure
- [ ] T10.6 Git identity (owner action)

### Phase 11
- [ ] Final verification, clean clone, report, HANDOFF

## Phase 7 measurements (2026-10-18, optimised `-c release -DDEBUG` build, M4 Air, interleaved with a build of 5e7f5ee)
| Metric | Before (5e7f5ee) | Now | Target | Met? |
|---|---|---|---|---|
| Themes warm scroll CPU | 43.7–45.8% | 45.0–49.0% | ≤ 20% | no |
| Gallery warm scroll CPU | 37.9–46.1% | 29.5–60.0% (noisy) | ≤ 20% | no |
| Wallpaper warm scroll CPU | 99.7–102.5% | 90.6–96.0% | ≤ 20% | no |
| Themes page switch, worst main-thread hold | — | 75–140 ms (first 390 ms) | none > 100 ms | no |
| Gallery card build, release | — | median 11.9 ms, worst 72.5 ms (first) | ≤ 16 ms | median yes |
| Seconds clock visible / covered | 2.5% / 1.4% CPU | 0.38–0.41% / 0.04–0.13% CPU | ≤ 1% | yes |
| Dock app idle, widgets on, desktop covered | 0.5–0.8% CPU, ~2.4 wakeups/s (`top idlew`) | — | ≤ 1% / ≤ 5/s | yes (covered case only) |
Profiling: the Themes switch cost is SwiftUI attribute-graph work for the page as a whole (attributed through ThemeAtmosphere's GeometryReader), not preview drawing; release builds show no 2 s preview stall (that figure was a debug build on CI). Wallpaper scroll cost is mostly the 1,000-card library; a 120 ms thumbnail-decode deferral was tried and showed no measurable gain, so it was reverted.

## Timer audit (T7.5, 2026-10-18)
| Timer | Interval / tolerance | Runs only when | Off when feature off / covered / locked / asleep |
|---|---|---|---|
| Widget corner poll (`DesktopWidgetController.pointerWatch`) | 50 ms / 20 ms | Arrange mode, widgets shown, a widget not occluded | yes (since 3040d75) |
| Widget drag watch (`dropWatch`) | 50 ms / 10 ms (added) | a gallery card is being dragged | yes |
| Clipboard check (`ClipboardMonitor`) | policy pace (0.5–2 s) / half | history on **and** Clipboard extra on | yes |
| Wallpaper coverage (`WallpaperController`) | 2 s / 0.5 s | live wallpaper paused because covered | yes |
| Knock watchdog (`KnockListener`) | 1 s / 0.5 s | the motion sensor is open (TapTap extra on, knocks on, an action set) | yes; sensor closes on sleep, display sleep and lock |
| Island pointer backstop (`NotchController`) | 150 ms / 50 ms | the island is expanded | yes |
| Scroll relief watchdog (`MainWindow`) | quiet/2 / quiet/4 | a scroll view in the main window is live-scrolling | yes |
| Ticking text (`TickingTextLayer`) | 0.1 s stopwatch, 0.5 s seconds clock / 20% | the widget is visible and ticking | yes |
| System sampler (`SystemMonitor`) | policy pace; idle pace with no viewer | always (island/menu bar/widgets read it) | slows to the idle interval with nothing showing it; not paused on lock |
Idle wakeup budget measured: Dock app, widgets on, desktop covered: ~2.4 wakeups/s, 0.5–0.8% CPU (`top -stats idlew`); `powermetrics` needs sudo, which this run doesn't use.

## try? audit (T8.4, 2026-10-18)
Before: 504 (`grep -c "try?"` over Sources). After: 506 (moved code, no new silent ones).
- File operations on the person's data (videos folder, deleting a video or imported picture, the clipboard and shelf folders and their files, the desktop journal's preview record): now `FileAttempt.run`, which logs every failure. 8 sites.
- File operations on caches and temporary files (GitHub, weather and search caches, theme previews, diagnostics zip work folder, screenshot temp file, wallpaper stills, library downloads in progress): `try?` kept, each with a "Best effort" comment. 20 sites.
- Already checked (`(try? …) != nil`, with the failure handled): left as is.
- `try? await Task.sleep`: 152, all cancellation of a sleep, which is the intended way to stop: left uncommented.
- Decoding with a fallback (`try? decode…` in tolerant decoders): 137, by design (an unreadable field falls back to its default): left uncommented.
- Other: ~197 (dlsym/regex/optional parses, Process.run with its own error path, etc.): **not individually reviewed or commented**; that part of T8.4 is open.
