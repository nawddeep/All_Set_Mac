# Studio Originals — 2026-10-08

Added a separate **Studio Originals** collection with 25 original theme concepts and 260 individually selectable theme widgets. It has its own Themes shelf/filter and its own group in the Widgets gallery.

## Finished image-led themes

Five newly supplied artworks are bundled and applied:

- Halo Atlas — blue orbital geometry over a reflective horizon
- Arc Theory — a luminous blue planet traced by precise arcs
- Ember Eclipse — copper eclipse over misty mountains
- Tideglass — pearlescent waves beyond the mist
- Static Star — a quiet starfield above layered mountains

Each has a bespoke widget arrangement, widget mix, type treatment, palette, copy and card selection. None reuses a complete layout from Desktop Edit or another finished Studio Original. One additional artwork is visible in the conversation but is not yet available as a local file, so its mapping remains unchanged until the file is supplied. The other concepts retain temporary native-art foundations until their final images arrive.

## Artwork and performance

The five new JPEGs total about 2 MB and ship locally in `Sources/AllSetCore/Resources/ThemeArt/`. No artwork was generated after the user requested prompt-only handling.

Artwork is still, theme previews remain cached, and widget motion is disabled for this collection. The DEBUG render harness measured 12,500 indexed theme-widget lookups at 0.34 ms versus 1,419.07 ms for full-catalog scans.

## Verification

- `swift test`: 438 tests in 102 suites passed.
- Rendered and visually inspected the six complete desktops, cards and widget sheets in `build/review/studio-originals-six/`.
- Corrected Ink & Ivory's note color after visual review.
- Rebuilt, signed, replaced and launched `build/AllSet.app`.

No commit or push was made.
