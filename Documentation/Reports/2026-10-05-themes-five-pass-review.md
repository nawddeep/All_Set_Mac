# Themes: five quick review passes — 2026-10-05

The user requested five quick passes on Themes only, comparing the approved image with the app and checking details, background, behavior and core performance. A deeper correction round depends on their next instruction. Wallpaper work remains deferred.

**Result: the core checks pass and sampled scrolling is consistent, but the visual match is partial. Themes should not be marked finished against the reference yet.** Live search automation also has an unresolved result.

## Evidence and scope

- Reviewed source checkpoint: `80dae18`, Themes filter bar/cinematic theme/art resources.
- Approved image: `design/themes-concepts/2026-10-05-cinematic-reference/themes-preview.png`.
- Fresh native page renders: `build/review/themes-five-pass/renders/`, at 900×600, 1120×760, 1400×900 and 1728×1080, both at the top and scrolled 550 pt. All eight inspected.
- Side-by-side: `build/review/themes-five-pass/reference-vs-current.png`. The right panel is the native rendering harness at 1400×900, rather than a screenshot of the live Dock window. Images are fitted to comparable panels; this is a visual comparison, not a pixel-difference score.
- Actual installed-app capture: `build/review/themes-five-pass/live-dock-app.png`. Live checks targeted PID 79452 at the exact pinned bundle, `build/AllSet.app`, scoped to the main All Set accessibility window.
- The main window was closed at the initial live check; opening the existing bundle made it available. At final inspection the main window was no longer listed on screen. Window visibility/focus during automation was therefore not completely controlled.
- Strict/deep code-sign verification passes. Installed and `.build/release/AllSet` executable `__TEXT,__text` SHA256 both equal `349e47046e35f5559f6c64e2102562f9c4934770d52d82e60d15ba263eecfc76`.
- This round changes documentation and review artifacts only. No implementation edits, rebuild, commit or push were performed.

## Five passes

| Pass | Result | What it establishes |
|---|---|---|
| 1. Composition, background and lighting | Partial match | The five-card spotlight, landscape center, portrait neighbors, Featured badge, pagination and centered actions are present. The reference's sharp blue/violet neon rim, reflected floor and scenic backdrop behind navigation are much stronger. The app has a softer cyan atmosphere and a faint ground pool. |
| 2. Details and responsive layout | Needs polish | All four sizes render with an accessible fixed category/search toolbar; narrow widths show the overflow menu. Card captions sometimes collide with text baked into their preview. Small windows make the twelve center widgets very small and truncate a neighbor's name. Moodboard tiles are below the initial viewport even at 1728×1080, unlike the reference's fully visible Moodboard strip. |
| 3. Live Dock-app controls | Partial / search unresolved | Next/previous change and restore the selected hero; Football removes the discovery hero; All restores it. A real-click/typed matching search returns the single Aurora result. Query replacement was not reliable in the automated run, so unmatched search and uninterrupted replacement are not marked passed in this round. Clear search and Aurora pagination restore the browsing state. |
| 4. Core, carousel and cache | Pass | Fresh targeted Swift tests: 25 tests in five suites. Native optimized probe: 30 checks, including looping, wheel/swipe direction, vertical page scrolling, click passthrough, Reduce Motion, per-image observation isolation, purge notification and reload. |
| 5. Scrolling and rendering cost | Pass within sampled harness | Two six-second optimized Themes scroll passes: zero >33 ms hitches, p95 17.9–18.1 ms, maximum 18.7–18.9 ms. App CPU is 48.1–48.5%. This is a brief harness sample, not a hardware frame-rate guarantee or a demonstrated improvement. |

## Visual findings for a possible deeper round

1. **Restore the reference's lighting and depth.** Current center artwork and edge light lean cyan. The reference has a clearer violet edge, reflected cards, stars and mountain silhouette behind the navigation. The app's broad atmosphere remains conspicuous further down the page where the reference becomes darker.
2. **Reduce competing content in previews.** The real twelve-widget Aurora desktop is more densely packed than the reference's larger, simpler clock/weather/calendar/music composition. Neighboring art also follows the existing catalog rather than the reference's invented Golden Escape / Electric Stadium / Sage Ritual themes. Dynamic time/weather and real category counts are expected to differ and are not failures.
3. **Tighten vertical hierarchy.** The taller header, larger hero/action area and Trending cards consume more of the first viewport. At 1400×900, Moodboards are absent from the initial view; at 1728×1080, only their heading reaches the bottom. The reference exposes their full tile strip.
4. **Protect card captions.** Seven's name crosses existing lettering in its preview; other shelf and Moodboard overlays compete with baked-in labels. A few existing photo/VHS previews show empty scanline/placeholder content rather than finished photography. Core geometry tests do not verify image completeness or caption legibility.
5. **Check shelf bounds and search focus in a controlled live session.** Horizontal rails intentionally overflow at narrow widths, but even the wide five-card rail slightly crops its last card near the vertical scrollbar. Live search input needs a confirmed result before it can be signed off.

The simplified single-surface toolbar follows the user's later request to fix the odd nested bar. Its difference from the reference's separate pills is intentional. Inactive labels, integrated search, and one selected white pill avoid the nested outlines in the supplied complaint image.

## Core and interaction checks

Commands and raw evidence:

```sh
swift test --filter 'ThemeCarouselLayoutTests|ThemeLibraryTests|ThemeCardArtTests|ThemeAccentTests'
.build-probe/release/AllSet -probe carousel -skip window,wallpaper,widgets,notch
ONLY=themes .build-probe/release/AllSet -probe scroll -skip window,wallpaper,widgets,notch
```

Logs: `core-tests.log`, `carousel.log`, `scroll.log`, `scroll-environment.log`, `render.log`, `live-controls.log`, `restore.log`, and `executable-verification.txt`, all under `build/review/themes-five-pass/`.

The 25 targeted tests are the fresh result for this round; the prior full 312-test run was not repeated. The carousel/cache probe uses the existing optimized DEBUG executable; live controls use the installed signed release.

The first live helper assumed every theme name was exposed as an AXValue; correcting it to inspect AXDescription/AXTitle resolved that assertion problem. Subsequent keyboard-only AX focus attempts did not reliably enter text. A guarded real mouse click allowed the first query, but replacement with `zzzznomatch9876` still left the prior query in the logged run. The app window's visibility also changed during the review. These observations establish incomplete automated verification, not a proven app search defect. Earlier attempts are retained separately; the final live log contains the unresolved failure rather than disguising it as a pass. Restoring through Clear search / All / Show Midnight Aurora succeeded.

Apply Theme, Preview on Desktop and favorite mutations were not exercised. The user's desktop configuration remains outside this review.

## Performance limits

The optimized harness uses a 1280×800 window at 1% opacity, holds off App Nap and posts native live-scroll notifications. CPU measures the probe process. First and second passes contain 347 and 348 sampled intervals respectively and scroll a 1980 pt range.

WindowServer accumulated 8.66 CPU seconds over the whole 17.53-second run, about 49.4% CPU. This is system-wide and includes the Dock app and other activity. GPU utilization was not isolated. There is no controlled baseline in this quick round, so neither an improvement nor a regression against earlier runs is established.

The next step, on the user's call, is a deeper Themes-only round focused on the findings above. Wallpaper remains pending until Themes is accepted.
