# Session report: 2026-09-27, scene stills made into moving wallpapers

Full log: "Making the stills move" in `docs/wallpaper-import.md`. Branch `perf-audit`.

## Done
- Asked whether the pkg/json behind each preview could be made live. **It can:** 79 of the 106 stills carried motion data (parallax depths, foliage sway, water, shake, cloud drift, scroll, pulse).
- **63 stills are now seamless looping videos**, rebuilt from the scene's own numbers, since Wallpaper Engine's shaders can't run here. The library is now **138 live, 43 stills** (was 75/106).
- **Measured, not assumed:**
  - the loop joins exactly (0.000 of 255 between first and last frame);
  - a loop is only kept when `frame_movement()` sees real movement — **16 were rejected** and stay sharp stills;
  - all 63 play (`playcheck.swift`), and all 63 first frames were checked on contact sheets.
- **Made it affordable:** layers are prepared once instead of per frame, and non-moving runs are flattened. 2.25× the resolution for the same time.
- 205 tests pass, 0 warnings, Dock app rebuilt and relaunched.

## Open
- The motion is a faithful rebuild, not the original shader: layers move as wholes rather than warping.
- A loop is softer than the 4K still it replaces and runs the decoder; the 0.8 threshold is the dial.
- Earlier items stand: fast-scroll hitches, the F15 seconds-clock decision, merging and pushing `perf-audit`.
