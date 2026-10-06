# Video-only Wallpaper and widget spotlight motion — 2026-10-06

Wallpaper opens directly to the existing video library. The entire source/search/favorites bar and the Aerial Videos, Art, and My Videos source tabs are removed. Widget spotlight lighting now follows the actual widget footprint; size and material selections have sliding indicators in both the main page and Customize sheet.

## Implementation and data

- `WallpaperPages.swift` always mounts `VideosSection`; imported videos, the 986-entry library, drop/import, category/sort/Owned filters, previews, and details retain their original paths. Search lives inside the library; category filters scroll horizontally at narrower widths. Only the shared 102 pt navigation overlaps the full-bleed hero.
- Removed `WallpaperSourceBar.swift`, the unused cinematic Wallpaper replacement, its unused backdrop/state, the Aerial UI, and the `AerialCatalog` manifest/preview/download service. There are no Aerial services or source-tab state left in the app. Legacy Art deep links open the video library.
- These sources did not have SQL database tables: Aerial used a cached JSON manifest and previews; Wallpaper Art choices came from shared generative art models. The retired active Aerial cache (71 files), its one downloaded video, and one retired preference key were moved/backed up under `build/backups/retired-wallpaper-sources-2026-10-06/`. The original cache directory is absent after the legacy baseline probe. Personal video library/catalog/server records were not deleted. Shared art rendering remains necessary for Themes and existing widgets, and no longer registers a Wallpaper Art source.
- `WallpaperCategory` replaces the video library's dependency on `Aerial.Category`, preserving all six JSON raw values. Existing imported and server catalogs load unchanged.
- `StudioLayout.fitting` supplies one aspect-correct frame for preview, cached shadow, and floor light. The container animates between footprints using the existing responsive motion. Square S previews and wide M previews use different frames; the surrounding stage stays stable.
- `StudioSegmentedControl` uses a separate matched-geometry namespace per size/style control, existing theme colors and timing, selected accessibility traits, and reduced-motion alternatives. Customize reuses the same controls.

## Verification

- Debug build, repeated full test run, and release packaging passed with no warnings. **336 tests / 85 suites**: removed two obsolete Aerial service tests, added four regression tests covering legacy category decoding, square versus wide lighting, every catalog size at four window widths, and invalid geometry.
- Native Dock app checks: Focus Timer S square and M wide; all five styles (Photo, Solid, Outline, Mesh, Dark) selected successfully; Customize changes S/M/L/XL sizes and Mesh/Dark styles successfully in the final release; Wallpaper opens with no source bar; search returns no-results and clearing restores the grid; scrolling advances the scrollbar to 0.028507 and keeps navigation visible. The library still reports 829 live + 157 stills, 21 local / 965 server.
- Inspected all 12 final spotlight captures: Focus Timer, Analog Clock, Weather, Calendar, System Monitor, and Music at 900×600 and 1280×800. Also inspected the clock, Themes, and Wallpaper captures and native screenshots. Artifacts: `build/review/video-library-widget-motion-2026-10-06/`.
- Early `spotlight-renders/` files retained the previous Focus Timer state under other filenames: the harness switched pages before its 300 ms removal transition completed. These are **not passing evidence**. The harness now waits 700 ms; the 12 files in `spotlight-renders-final/` show the correct individual widgets. Extra cases are opt-in, preserving the normal CI/probe page inventory.
- Several native actions were interrupted by concurrent user interactions. Earlier interrupted Customize selection attempts are not counted as passing; the later final-release Customize selections, main-page selections, and visible results above are confirmed. A final carousel action was interrupted when the user switched to Themes, so it is not counted as passing. No desktop Add/Delete/Apply action was used for verification.

## Performance

Debug scroll probes use the same gallery before/after. Wallpaper has only an after measurement because its default source/content changed; an Aerial-versus-library comparison would be misleading.

| Run | CPU (one core) | p95 gap | Worst gap | >33 ms gaps |
|---|---:|---:|---:|---:|
| Gallery before, first | 49.9% | 23.6 ms | 78.5 ms | 5 |
| Gallery before, warm | 30.8% | 18.4 ms | 23.4 ms | 0 |
| Gallery after, first | 68.2% | 25.3 ms | 43.0 ms | 1 |
| Gallery after, warm | 34.0% | 18.3 ms | 25.9 ms | 0 |
| Wallpaper after, first | 80.2% | 21.6 ms | 49.8 ms | 1 |
| Wallpaper after, warm | 76.2% | 21.2 ms | 31.8 ms | 0 |

Shared counters over the same intervals: Gallery WindowServer 51.43% → 51.47%, median device GPU 46.5% → 44%; Wallpaper WindowServer 63.04%, median device GPU 46.5%. These are whole-Mac counters with concurrent user activity and live media. There is no isolated CPU/GPU/WindowServer improvement claim. Warm scrolling has no >33 ms gaps; first-load preview work remains a limitation. The new controls animate only on selection changes and lighting remains cached/static.

## Delivery

Exact Dock bundle: `build/AllSet.app`, development-signed; strict signature verification passed. Final native launch was verified; the user subsequently selected Themes. Final launch identity is recorded in `build/review/video-library-widget-motion-2026-10-06/bundle-identity.txt`. All work is local. No commit or push.
