# Session report: 2026-09-26 (evening), performance audit

Full log: `docs/perf-audit.md`. Branch `perf-audit`, not merged or pushed.

## Done
- **Phases 0–5 of the audit.** Profiling works on this Mac: `xctrace` Time Profiler plus `leaks`, `heap` and `footprint`. `powermetrics` needs sudo.

**Fixed, with measurements:**

| Fix | Before | After |
|---|---|---|
| Main window released on close: CPU | 0.89 % | 0.10 % |
| Main window released on close: Themes page memory | +264 MB, kept | +7 MB, freed |
| Covered widgets pause their timelines (seconds clock) | 12.7 % | 0.04 % |
| Idle stats monitor, quick samples only | 0.09–0.11 % | 0.03–0.04 % |
| Retain cycles (`leaks`) | 1 | 0 |
| Launch CPU, first 15 s | 1.71 s | 1.59 s |

Also fixed:
- **Byte-limited caches:** a least-recently-used `CostCache`, 8-bit previews and artwork, and a memory-pressure response.
- **`PerformancePolicy`:** Low Power, heat, battery and Reduce Motion in one place; network refresh slows in the saver tiers.
- **Event-driven calendar.**
- **Screenshot undo:** capped at 24 versions.
- **Search cache:** capped at 200 pages.
- **Wallpaper:** coverage checks only when it moves; the system still isn't rewritten at launch.

**Verified:** 200 tests pass, 0 warnings, previews checked visually, and the Dock app is rebuilt from the branch.

## Open (needs the user)
- **F15:** a *visible* clock with seconds costs 9–12 %. Option A: Core Animation digits. Option B: seconds without the rolling animation.
- **Themes previews drawn from scratch:** peak 738 MB (render with preview-sized photos to fix).
- **Launch spikes to 278 MB**, briefly.
- **Frame-rate alignment:** recommended, not done.
- Merge `perf-audit` into `main`, and push, when the user says.
