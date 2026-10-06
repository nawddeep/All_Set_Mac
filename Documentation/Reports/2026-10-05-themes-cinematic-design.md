# Cinematic Themes design — 2026-10-05

The user selected `design/themes-concepts/2026-10-05-cinematic-reference/themes-preview.png` and authorized implementation plus updating the app pinned in the Dock. The project review is in `2026-10-05-project-review.md`. This work implements the selected Themes frontend; the broader engineering findings and other tabs remain separate work.

## Result

- Dark cinematic atmosphere, existing two-level navigation, pinned category pills and search.
- Five visible spotlight cards: complete landscape desktop at the center, portrait neighbours, continuous morphing geometry, cyan/violet border, static floor glow and reflection. Seven curated themes loop through the carousel.
- Theme name, widget count, Apply Theme, Preview on Desktop, Favorite and options sit beneath the imagery. These use the existing services, including Turn Off Theme for an active theme and the include-wallpaper preference.
- Trending desktop collages, five Moodboards shortcuts, responsive horizontal shelves with arrows and See all. Filters and search show actual matching themes in the existing results grid.
- Midnight Aurora is a real 12-widget set, with original generated artwork shipped offline. `ImageSource.bundled` supports decoding, persistence, wallpaper and widget previews. Packaging includes the JPEG; missing app resources return nil safely.
- Shared preview cancellation now honors other visible consumers. Preview tasks retain requests until cancellation, including during changes between desktop and portrait variants.

The approved mockup guides composition; previews contain the app's actual widgets and local content. Existing personal images were not copied into the repository. No backend, desktop layout migration, commit or push was performed.

## Verification

| Check | Result |
|---|---|
| `swift test` after final resource resolver change | 312 tests, 85 suites, pass |
| Debug/release warnings-as-errors builds | Pass |
| Final packaging | Release build succeeds; no compiler warnings |
| Native carousel probe | All 27 checks pass, including continuous swipes, wheel input, axis locking, looping and Reduce Motion |
| Visual captures | Themes, Seven detail, Gallery and Wallpaper; 900×600, 1120×760, 1400×900 and 1728×1080, including scrolling |
| Final clipping check | Additional 1400×900 Themes capture after scroll clipping change |
| Installed signature | `codesign --verify --deep --strict` passes |
| Installed executable | `__TEXT,__text` SHA256 matches release binary; whole-file hashes differ because app packaging signs the executable |
| Live release controls | AXPress succeeds for next/previous carousel arrows, Football/All categories and Midnight Aurora pagination; typed search returns Search results / 1 themes, then cleared |

Artifacts and logs are under `build/review/selected-design/`. The actual installed app is captured in `dock-app-themes.png`; `final/` contains the size matrix and `verified/` the last scrolling check.

## Performance

Optimized DEBUG harness on this M4 MacBook Air, Themes only, two six-second scroll passes:

| Run | App CPU | p95 frame interval | Maximum interval | Hitches >33 ms |
|---|---|---|---|---|
| New design, initial | 29.3–29.7% | 18.4–18.5 ms | 18.6–18.7 ms | 0 |
| New design, repeat | 30.8–30.9% | 19.5 ms | 19.9–20.5 ms | 0 |

Whole-run WindowServer CPU was 41.6%. This sample includes all visible apps and is not isolated GPU utilization. Hardware GPU utilization was not measured. Cached images, static gradients and opacity/transform motion avoid live widget trees or animated blur inside scrolling cards.

The saved earlier optimized binary measured 14.2–18.2% CPU, p95 18.8–18.9 ms, no hitches. It displays an older library layout with different content and scroll range (2228 vs 1850 pt); it is not a comparable HEAD build. The new composition costs more app CPU than that older layout; no speedup is claimed. These hidden-window harness figures do not guarantee identical behavior on other Macs or a first uncached visit.

## Dock installation

- Exact pinned bundle: `/Users/pratiksmac/Downloads/all set/build/AllSet.app`, identifier `com.pratik.allset`.
- Built with `scripts/build-app.sh`, signed with the existing All Set Development certificate, launched explicitly with `allset://open/themes`.
- Running installed bundle verified through NSWorkspace and process path (PID 70989 at verification); original aurora JPEG is present in its Resources (588,569 bytes).
- Executable code-section SHA256: `4aea2a6a56ff60d88c881dd4cbb768908926e2baf9407d7eade4662c0c3ffa3e`.
- Previous app saved at `build/backups/AllSet-before-cinematic-2026-10-05.app`.
- The desktop Apply/Preview controls remain connected but were not activated during frontend verification, preserving the user's current desktop.

## Artwork

Mode: built-in `image_gen` via the imagegen skill. One original landscape asset, generated without reference images, inspected and converted to JPEG quality 91. Workspace asset: `Sources/AllSetCore/Resources/ThemeArt/midnight-aurora.jpg` (1586×992). Exact prompt and mode are recorded in `design/themes-concepts/2026-10-05-cinematic-reference/aurora-asset-prompt.json`.

## Next session

Let the user review the Themes page in the Dock app before starting another tab. Keep cached previews and the reduced-motion contract. The user's next frontend direction determines the next scope.
