# Supplied Funky Themes integration — 18 October 2026

The user supplied 20 flattened desktop mockups in `/Users/pratiksmac/Desktop/themes_update/` and authorized adapting them for All Set. The original files are unchanged. The app now contains all 20 as installable, editable themes in the **Funky Themes** collection, bringing the catalogue from 111 to 131 themes and from 1,142 to 1,310 included theme widgets.

## Delivered

| Batch 1 | Batch 2 |
|---|---|
| Midnight Scrapbook | Velvet Cherry Noir |
| Pink Motel Pop | Blue Haze Diary |
| Cream Indie Diary | Olive Paper Studio |
| Chrome Fang Editorial | Electric Pop Grid |
| Lace City Noir | Plum Stardust |
| Vinyl Blossom | Sepia Library Club |
| Paper Hearts Cafe | Silver Bubble Goth |
| Acid Starlet | Peach Film Bloom |
| Soft Grunge Polaroid | Forest Ink Moodboard |
| Monochrome Diva | Cream Mod Poster |

Each set has its own source-derived artwork, palette, typography, photo crops and text. Its clock, calendar, music, checklist, photo, quote and ornament pieces use the app's existing live widget models. Photos and text can be changed in the existing widget inspector. All 168 included widget instances are also exposed through the existing Widgets UI. Layouts use one of five compositions chosen to keep the artwork visible and avoid filling the desktop edge to edge. Installation fits the group to the available display area and caps enlargement at 1.1×.

The source images are 1586×992 flattened mockups, with desktop UI painted into the pixels. `design/provided-funky-themes/assets.json` records the explicit crops and `scripts/prepare-provided-themes.swift` deterministically prepares 20 native paper backgrounds plus 60 photographic crops. The bundled backgrounds are 2880×1800 compositions made from a plain tone and selected original artwork. Their pixel dimensions do **not** mean the cropped artwork gained detail. The app never displays a frozen copy of the source clock, menu bar, Dock or checklist behind live widgets.

The look is an adaptation of the provided designs. Movable torn-paper edges and tape were not present as separate assets, so photos use the existing polaroid and collage frames. Small photo crops inherit the resolution of the mockup and may look soft at larger sizes. The source images can still be used to improve fidelity later if clean layered art or original photos become available; no new standalone themes or AI-generated images were made.

## Verification

- `swift test --filter FunkyThemeTests`: all 4 focused tests passed. They check registration, content, image decoding, editable photo slots and no-overlap fitting at 800×600, 1440×900 and 1920×1080.
- `swift test`: all 473 tests passed. README and CONTENT totals were regenerated from `ContentCountsTests`.
- The app's debug renderer produced a theme card, set preview, widget gallery and native desktop render at both 1440×900 and 1920×1080 for all 20 themes under `/tmp/allset-funky-test-home`. The contact sheets in `build/review/supplied-funky-2026-10-18/` were inspected for artwork, spacing and readable widget surfaces.
- The rendered themes use the existing Themes page and Widgets UI; the carousel hero layout was not changed.

The release bundle is built by `scripts/build-app.sh` into `build/AllSet.app`; build/signing verification is recorded in the final task response.
