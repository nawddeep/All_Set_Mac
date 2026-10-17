# Production readiness: report

Run of 2026-10-17/18 on branch `fix/production-readiness`, from `5e7f5ee` (a snapshot of the uncommitted work that existed when it started). 45 local commits, **not pushed**. Decisions and how to reverse each: `DECISIONS.md`. Owner's to-do and blocked items with evidence: `OWNER_ACTIONS.md`. Checklist, baseline and measurements: `PRODUCTION_READINESS_PROGRESS.md`.

"Verified" below means a check was run and seen to pass. Everything else says what wasn't checked.

## The 37 findings

| # | Finding | Status | What changed | Commits | How it was verified | Not verified / remaining |
|---|---|---|---|---|---|---|
| 1 | GPL Lid Plane, no LICENSE | Fixed | Lid Plane removed (code, tests, page, flag, notices); proprietary LICENSE with third-party notices | c5192d2, 9ef3e7b | Build, 436→ tests pass; repo grep finds no Lid Plane/GPL in shipped code | Licence name/choice is the owner's to confirm |
| 2 | Empty Wallpaper page; Workshop content | Fixed | 36 built-in live wallpapers shown first; WE tooling moved out; WE never mentioned in the app | 95d153e, 214e7b7 | `-renderPages` on an empty throwaway home shows a full page; tests | No commissioned original video wallpapers (owner) |
| 3 | Celebrity names, trade dress | Fixed | Football/music themes rewritten around invented players, clubs, fixtures; nicknamed ids renamed with legacy mapping | b3d5a00 | `RealPeopleDenylistTests` scans catalog data and every source file; legacy-id tests | Counsel review of kit colour presets (DECISIONS) |
| 4 | No Developer ID / notarization; wrong Gatekeeper text; TCC resets | Partly (owner) | `scripts/notarize.sh` wired into release.yml; macOS 15+ Open Anyway instructions | 27723fe | YAML parses; script syntax-checked | Can't notarize without the Developer ID (owner) |
| 5 | No entitlements | Fixed | `Resources/AllSet.entitlements` (calendars, audio-input); hardened runtime on every build | 716b506, 0c87e63 | Signed app shows runtime flag and entitlements; runs 30 s, no entitlement errors; Now Playing helper runs | Calendar events, mixer routing, hotkeys under hardened runtime not checked by hand |
| 6 | Home server as public; psql per request; SQL interpolation | Fixed (server), plan for public | `pgsql.py`: values only as psql variables or COPY data; catalog cached 30 s; paging after file filter; docs say what the server is; R2+CDN plan | 74b6e2f, efd3c33 | 117 server tests incl. hostile ids/emails/titles; lint test bans hand quoting | Public backend not built (owner decision) |
| 7 | Never clicked through; untested matrix | Partly | `-smokeTest` walks onboarding, every page, widget ops, theme+undo, wallpaper, extras, ⌘⇧5; CI job; release checklist | 9231928, e07a4bd | Smoke 44/44 locally on throwaway data | The manual matrix (macOS 14/15, monitors, VoiceOver…) needs a person |
| 8 | Knock shell commands | Fixed | `.shellCommand` removed; old ones load empty with a one-time notice; knocks off for new installs; launch targets validated | 83b1b68, 185a548 | Migration and validation tests | — |
| 9 | False privacy statement | Fixed | Data & Privacy rewritten; Network use list from `NetworkUse`; ask before first AI send | 208b3a4 | `NetworkUseTests` checks every address in source | Not compared against a firewall log (release checklist) |
| 10 | ⌘⇧5 takeover; no uninstall | Fixed | Default ⌃⌥⌘5; ⌘⇧5 asks first; Restore macOS settings; Uninstall…; `scripts/uninstall.sh`; pure tested take/restore logic | 6fed5d6, 68980ed | Plan tests; smoke takes ⌘⇧5 and gives it back exactly | Uninstall and the script not run (they'd change this Mac) |
| 11 | `sudo purge` button | Fixed | Removed | 230b79f | Build; grep | — |
| 12 | Permission sprawl; no onboarding | Fixed | Extras off by default; permissions asked when an extra is switched on; status rows; onboarding | 2f3b21c, d3837b0 | Tests for extras/permission logic; onboarding rendered and walked by smoke | Denied/revoked flows on a real Mac (checklist) |
| 13 | Deep links act silently | Fixed | Length/charset checks, 2 s throttle, Undo bar, ask when not in front | f673aaa | Parsing/throttle tests | "Not in front" judged at delivery; not tried from a browser |
| 14 | Perl/MediaRemote hack | Mitigated | 3 s ready deadline, ≤3 retries (2/4/8 s), kill switch, status | 66f5332 | Backoff test; helper runs in the signed app | Still a private interface by nature |
| 15 | Private APIs everywhere | Mitigated | `Capabilities`: kill switch + status for 7 interfaces; motion sensor open times out | 66f5332 | Capabilities tests; Compatibility section | — |
| 16 | 14.2 never tested; Intel unstated | Partly (owner) | Apple Silicon only; CI builds arm64-apple-macos14.2 | 6a6b12e | That build passes locally | Never run on real macOS 14/15 (owner) |
| 17 | 43–48% scroll CPU; 2 s stalls; 70 ms cards | **Blocked** | Measured honestly; built-in tiles cached; one experiment reverted | 3040d75 | Release probes: card median 11.9 ms (met); no 2 s stall in release | Scroll 41–100% vs 20% target; Themes switch 75–140 ms. Needs page redesign |
| 18 | 20 Hz pointer poll; timers | Fixed | Poll only in Arrange mode; timer audit with tolerances | 3040d75, af4cc40 | Audit table; idle 0.5–0.8% CPU, ~2.4 wakeups/s (desktop covered) | `powermetrics` (needs sudo) not used |
| 19 | Seconds clock 9–12% | Fixed | Seconds in a CATextLayer; card redraws once a minute | 0d0f4aa | `-probe covered`: 2.5% → 0.4% visible | Not watched live by eye |
| 20 | CI probes on debug, GPU-less | Fixed | Probes on optimised build; ceilings from measured + 25%; idle probe | a0fadd4 | Local full probe run passes the budgets | First CI run may need re-basing (budget file explains) |
| 21 | AppServices god object | Mostly | Feature coordinators own stores and start/stop | e79f889 | 464 tests; app runs | UIState not split |
| 22 | Giant files; 5-file widget registration | Mostly | No file over 600 lines; kind metadata/defaults one file each (identical before/after for 54 kinds) | 1219bbf, 2940725 | Dumps diffed; fixture round-trip test | App side (view/editor/looks) still switch-based |
| 23 | 487 `try?` | Partly | User-data file ops log via `FileAttempt`; cache ops commented | b5ba74a | Build, tests | ~197 non-file `try?` not individually reviewed (514 total now) |
| 24 | Unchecked Sendable, force unwraps, LidPlaneCapture race | Fixed (TSan blocked) | Each unchecked Sendable states its protection; fallible unwrap fixed; race went with Lid Plane | 11da6e5 | Review | TSan won't load on this Mac (3 attempts, evidence in OWNER_ACTIONS) |
| 25 | Zero localization | Scaffolded | `defaultLocalization`, en.lproj in the app, 45 AppKit strings localizable, CI lint | d2e9c72 | Lint passes; app bundle has en.lproj | No translations |
| 26 | No onboarding, auto-update, crash reports, uninstaller | Fixed (update key owner) | Onboarding, Sparkle (off until keyed), MetricKit + Export Diagnostics, uninstaller | d3837b0, 0c87e63, 6fed5d6 | App launches with Sparkle embedded, no update traffic | Update flow untestable until the key exists |
| 27 | Dead/duplicate code, stale docs | Fixed | Duplicate file names resolved; stale comments; docs rewritten | d497a30, d420791 | Grep: no TODO/FIXME/HACK; no double exit | — |
| 28 | App target untested | Partly | More logic in core with tests (⌘⇧5 plan, permissions, extras, links, onboarding, capabilities); smoke harness for the app | 68980ed, 9231928 | Tests + smoke | No XCUITest |
| 29 | Sleep-based, hardware tests | Fixed | `waitWhile` for 14 polls; racy sleeps replaced; hardware suites tagged and skipped on CI | e97dd62 | 5 consecutive full runs: 468/468 | 24 deliberate timing sleeps remain |
| 30 | No UI/integration tests or matrix | Partly | Smoke test in CI; release checklist | 9231928, e07a4bd | Smoke passes | Matrix needs a person |
| 31 | Docs bloat, 27 MB images | Fixed | Reports, design/, references moved to ../AllSet-personal; HANDOFF trimmed | 1dcc961, this commit | Hygiene check passes | — |
| 32 | Personal paths and emails | Fixed (history: owner) | Paths scrubbed; hygiene check fails on new ones | 3510f1f, 427e663 | Check catches a planted path | Emails in commit history (owner, needs force-push) |
| 33 | Squashed history, lost work | Process | Small commits per task; no rewriting | all | 45 commits | — |
| 34 | Contradictory counts | Fixed | Counts generated from code into README/CONTENT; test fails on drift | d420791 | Test passes | — |
| 35 | Restructure before tests | **Blocked** (by design) | Not run: stale plan, open questions, blocked prerequisites | 77cdbdd | — | Owner: answer Q1–Q3, regenerate plan |
| 36 | Feature soup | Fixed | Four pillars + Extras, off by default | 2f3b21c | Smoke toggles every extra | — |
| 37 | Wallhaven, hotlinks | Fixed | Wallhaven gone; Openverse licence-filtered; 150 photos verified CC0 and bundled | e2b36eb | Licence tests; Openverse records checked for all 150 | — |

## Performance, before and after
Optimised build (`-c release -DDEBUG`), M4 Air, interleaved with a build of `5e7f5ee`; the Mac's load swings these by ±10 points.

| Metric | Before | After | Target |
|---|---|---|---|
| Themes warm scroll CPU | 43.7–45.8% | 41–49% | ≤ 20% (not met) |
| Gallery warm scroll CPU | 37.9–46.1% | 29.5–60% | ≤ 20% (not met) |
| Wallpaper library warm scroll CPU | 99.7–102.5% | 59–96% | ≤ 20% (not met) |
| Themes page switch, worst hold | — | 75–140 ms (first 390 ms) | < 100 ms (not met) |
| Gallery card build, median | — | 11.9 ms | ≤ 16 ms (met) |
| Seconds clock, visible / covered | 2.5% / 1.4% | 0.4% / 0.1% | ≤ 1% (met) |
| Idle, widgets on, desktop covered | — | 0.5–0.8% CPU, ~2.4 wakeups/s | ≤ 1%, ≤ 5/s (met for this case) |

## Final counts
| | Start | End |
|---|---|---|
| Build warnings | 0 | 0 |
| Swift tests | 456 | 469 (+ smoke test 44/44) |
| Server tests | 107 | 117 |
| `try?` | 504 | 514 (8 file ops now logged, 20 commented; new code added some) |
| Largest source file | 1,666 lines | 596 lines |
| `@unchecked Sendable` | 13 (+ probe-only) | 13 (+ 4 probe-only), each with its protection stated |
| `nonisolated(unsafe)` | 5 | 4 |
| Swift source | 279 files / 59.6k lines | 325 files / 60.2k lines |

## Top owner actions
1. Apple Developer ID, then the five secrets, then a first notarized release.
2. Decide what content may be public; license or commission original wallpapers.
3. Sparkle key pair into the repository secret and variable.
4. Run `RELEASE_CHECKLIST.md` on macOS 14, 15 and 26, with two monitors and VoiceOver.
5. Decide how far to redesign Themes/Gallery/Wallpaper scrolling to reach the CPU target.
