# 2026-10-05: Themes hero redesign, H0-H2

Request: rebuild the Themes page as "Concept 2, Cinematic Carousel" (reference `docs/reference/concept2-reference.png`) in phases; v2 prompt H0-H7, one phase at a time, stop at each gate.

## Done
- Phases 0-6 and 1.5 (earlier): looping carousel, card art, rails, Reduce Motion / Low Power.
- **H0** audit, answers from the user recorded in memory. **H1** one nav cluster (rows 8 apart, solid scrim, row 2 rim 0.65).
- **H2** `ThemeAccent` + fallback and 12 curated accents; `.backdrop` preview variant (384x240, saturation x1.6, blur, fade, made once off-main); `ThemeAtmosphere` (base, wallpaper haze, primary pool, secondary haze, vignette, top darkening) with two-slot opacity crossfade; atmosphere also pinned under the nav; Seven's stray oval removed by cropping the card (focus top, zoom 1.64); probe asserts no blur while the carousel moves.
- Tools: `scripts/review-hero.sh` / `make review`, `-heroTheme`, `-renderThemeCards`, `-probe carousel`.
- `docs/UI-Spec.md`: complete measured spec.

## Checks
313 tests / 85 suites, 0 warnings. Carousel probe: 8/8 backdrops ready, 0 blurs while moving. Scroll CPU 42-43% vs 37-38% (HEAD), p95 19.2-19.7 vs 19.2-19.4 ms, 0 hitches. Warm page switch 96-137 vs 84-123 ms.

## Delta vs reference (1400x900, after H2)
1. Colour pool is flatter and less saturated than the reference's blue/magenta glow (Seven reads deep red, correct hue, lower presence).
2. Selected card lacks neon edge strip, ground glow and sheen (H3).
3. Neighbours tuck behind and read dark; reference has a gap and brighter own-colour rims (H3/H5).
4. Glass is flat: no gradient border or inner highlight, category rail is one strip not pills, no grain (H4).
5. Card art is busier (title + hero + 4 small) than the reference (title + 1 + 2); Americana and Albiceleste wallpapers carry a watermark (H5).

## Open
Atmosphere scroll cost (+5 points), flattening test not run; keyboard, drag and click only user-tested.
