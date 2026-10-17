# Production readiness: progress

Branch `fix/production-readiness`, cut from `4cbf666` plus snapshot commit `5e7f5ee` (the 92 uncommitted files from earlier sessions, committed as-is at the owner's request, 2026-10-17).

Owner's choices for this run (2026-10-17): snapshot first; remove Lid Plane and rename the football/music themes; fully autonomous, local commits, no push.

On a context reset: re-read the mission prompt (in the conversation), `HANDOFF.md`, this file; resume at the first `[ ]`.

**Current phase:** 7

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
- [ ] T7.1 Theme previews off the main thread
- [ ] T7.2 Gallery cards as stills
- [ ] T7.3 Pointer poll only in Arrange mode
- [ ] T7.4 Seconds clock on Core Animation
- [ ] T7.5 Timer audit
- [ ] T7.6 CI probes on optimised build

### Phase 8: architecture
- [ ] T8.1 Split AppServices
- [ ] T8.2 Self-registering widget kinds
- [ ] T8.3 No file over 600 lines
- [ ] T8.4 try? audit
- [ ] T8.5 Concurrency
- [ ] T8.6 Localization scaffolding
- [ ] T8.7 Dead code

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
