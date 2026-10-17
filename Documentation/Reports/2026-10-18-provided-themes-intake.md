# Supplied theme intake — 18 October 2026

> Historical intake record. The user later authorized adapting the flattened mockups. All 20 themes were integrated; see `2026-10-18-funky-themes-integration.md` for the result and remaining visual limits.

## Status and scope

Request: integrate all supplied designs into All Set, preserving the user's designs, and rebuild. Do not create replacement themes or generate artwork.

Read the supplied attachment, `Documentation/HOW_THEMES_ARE_MADE.md`, `Documentation/THEMES_IN_DEPTH.md`, and the current handoff. Inspected all 20 PNG designs in `themes_update`. The two batch folders each contain ten PNGs and no separate wallpaper, photo, or layered source assets. All 20 PNGs are 1586×992 flattened desktop mockups with painted widgets and a menu bar; 19 also show a Dock. No supplied title exactly matches a current theme title. The current documented catalogue contains 111 themes.

The attachment is explicitly adopted by the user's request (“I have given you the prompt as well”). Its relevant constraints are: show all decomposition tables before code; ask for clean backgrounds if only flattened mockups exist; do not invent or generate replacement artwork; stop and list unsupported styling before adding it; run the app only with a throwaway `CFFIXED_USER_HOME`.

**No theme implementation, image generation, asset repainting, app launch, rebuild or commit has occurred in this intake.** All 20 designs remain candidates for integration. A flattened mockup cannot be installed beneath live copies of its widgets without duplicating frozen clocks, dates, playback controls and checklists.

The source PNGs are unchanged. Inspection contact sheets are under `/tmp/allset-theme-intake/`. `design/provided-funky-themes/intake.json` records source hashes, dimensions and conservative cleanup rectangles in source pixels. Those rectangles identify what must be removed from a wallpaper export; they are not pixel-perfect repair masks or permission to repaint artwork.

## Batch 1 decomposition

| Supplied design | WALLPAPER: retain as fixed art | WIDGET: create as live/editable content | LOOK: observed direction |
|---|---|---|---|
| Midnight Scrapbook | Charcoal crumpled paper, torn scraps, tape, grid paper, dried flowers, butterfly, ink stars | Serif clock top left; calendar below; music top right; checklist right; central polaroids; handwritten quote | Black/cream, warm paper accent, serif time, handwritten quote, mono photos; rough paper card edges |
| Pink Motel Pop | Blush paper, large pink mouth and disco ball, leopard scraps, heart/star doodles | Flip clock, calendar, music, checklist, left photo prints and lower photo grid, note quote, large poster words | Cream/pink cards, black digits, rose accent, rounded cards, warm photos |
| Cream Indie Diary | Aged cream paper, torn backing scraps, tape, pressed flowers, newsprint | Thin serif clock, left calendar/music, right notes/quote, central photo stack and lower-right print | Oat/cream, brown ink, dusty rose accent, serif/handwritten text, faded warm photos |
| Chrome Fang Editorial | Chrome mouth sculpture on white, large chrome sparkle marks | Left clock/music/checklist/calendar cluster; upper photo tile and sparkle charm; bottom photo strip | Black/ivory cards, restrained silver-blue accent, serif time, mono photos, fine rounded corners |
| Lace City Noir | City skyline and water, lace curtains/borders, background candlelit ornaments | Left clock/music/checklist/calendar; moon picture; top-right wing picture; right small photo grid | Black cards, cream ink, silver lighting, serif time, mono photos, fine borders |
| Vinyl Blossom | Large flower/record composition and ivory ground | Clock left; calendar top middle; music right; checklist lower middle; top/right photo groups; quote | Ivory/blush cards, charcoal ink, rose accent, serif time, soft warm photos |
| Paper Hearts Cafe | Cream scrapbook paper, coffee ring, tape, pressed flowers, ink doodles | Clock/calendar/checklist left; music right; coffee photo; narrow photo strip; lower photo prints; handwritten quotes | Cream/cocoa, dusty pink accent, serif time, handwritten notes, warm photos; rough card edges |
| Acid Starlet | Acid-green/black collage, portrait art, checkers and large star graphics | Clock/music/weather left; calendar/checklist right; central/right photo tiles; quote cards | Near-black/cream with lime accent, condensed time, stark photos, sharp graphic edges |
| Soft Grunge Polaroid | Distressed gray paper, tape, flower drawings, moon-paper scraps | Separate date and clock; music, checklist, weather, quote; large polaroid group and small film strip | Gray/cream/mauve, muted rose accent, serif time, faded photos; torn card backing |
| Monochrome Diva | Winged silhouette, lace, pearls, satin and manuscript collage | Left clock/calendar/music/checklist; small photo tiles beside music and notes | Black/cream, serif time, mono photos, subtle warm/silver accent, thin borders |

## Batch 2 decomposition

| Supplied design | WALLPAPER: retain as fixed art | WIDGET: create as live/editable content | LOOK: observed direction |
|---|---|---|---|
| Velvet Cherry Noir | Burgundy satin, cherries, leopard paper, torn scraps and kiss marks | Clock/calendar/music/checklist; central photo grid; handwritten paper-note quotes | Wine-black/cream, cherry accent, serif time, handwritten words, warm red photos |
| Blue Haze Diary | Blue watercolor paper, rainy window, moon scraps and white flowers | Calendar/clock/music/checklist; left polaroid group; central photo grid; paper-note quotes | Cream/slate blue, navy ink, blue accent, serif time, cool photos |
| Olive Paper Studio | Olive/cream paper, botanical drawings, stamps, gold doodles | Clock/calendar/music/checklist; central photo grid; top-right print; handwritten quotes | Cream/olive, deep green ink, muted gold accent, serif time, warm photos |
| Electric Pop Grid | B&W collage, neon paint marks, checkers, lips/disco art | Clock/calendar/music/checklist; six-photo mosaic; quote notes | Black/white/pink cards, vivid lime/blue highlights, chunky condensed time, vivid photos |
| Plum Stardust | Plum sky, large moon, lace, floral silhouettes and stars | Clock/calendar/music/checklist; middle photo grid; left polaroids; right lower print; quote | Plum-black/mauve, pale pink ink, rose accent, serif time, cool faded photos |
| Sepia Library Club | Antique maps, books, lamp, typewriter, aged paper and ink | Clock/calendar/music/checklist; lower photo grid; left polaroids; quote note | Espresso/parchment, amber accent, serif time, sepia photos |
| Silver Bubble Goth | Chrome lips, chains, pendants, lace and disco-ball art | Clock/calendar/music/checklist; middle photo grid; left film photo; lower-right polaroid | Black/silver, cream ink, pink highlights, serif time, mono photos |
| Peach Film Bloom | Peach florals, sunlit balcony scene, film backing and paper scraps | Clock/calendar/music/checklist; central photo groups; handwritten note quotes | Cream/peach, brown ink, coral accent, serif time, warm film photos |
| Forest Ink Moodboard | Forest interior, branches, botanical paper, night landscape and wax seal | Clock/calendar/music/checklist; middle photo grid; left prints; quote notes | Forest-black/parchment, olive accent, serif time, subdued green photos |
| Cream Mod Poster | Cream paper, retro curves, checker scraps and abstract floral graphics | Clock/calendar/music/checklist; lower photo grid; left prints/notes; editable large poster words | Cream/rust/mustard/teal, black serif time, warm photos, geometric poster type |

These tables were shown in chat before any source changes. Colours are visual estimates, not measured final palette values. Existing supplied titles are retained. A suggested family label is **Funky Themes**, pending the user's naming preference.

## Existing capabilities versus exact visual gaps

| Requirement | Existing implementation | Remaining work or decision |
|---|---|---|
| Live clock/calendar/date | Existing clock, calendar and date kinds, digital/minimal/flip faces | Configure look and layout; do not reproduce the historical sample dates |
| Music controls | Existing Now Playing and vinyl kinds | Use actual media state; painted sample track labels are not a playback service |
| Checkable notes | Existing `todo` with `Kit.list` | Preserve checklist heading/look and existing editable task behavior |
| Quotes/poster words | Existing quote and wordArt with custom text styles | Remove all editable words from background; retain as editable text widgets |
| User-changeable photos | Existing photo and polaroids kinds, fullBleed/polaroid/inset/collage/filmStrip frames, theme personalization | Need the user's original separate photographs or clean exports; do not extract tiny previews and call them high resolution |
| Butterfly/wings/bow/heart/star/moon | Existing charm shapes; most also have sticker equivalents | No new widget kind or sticker shape is required |
| Palette, font, corner radius, filter | Existing theme look and per-widget options | Match per design, including mixed dark/light panels and readable bare text |
| Torn-paper card edges | Existing `.paper` is a solid regular card; no torn-edge treatment was found | Prefer a clean wallpaper with fixed torn-paper backings and bare widgets if the user accepts fixed decoration; movable/resizable torn cards require approved shared surface styling |
| Tape attached to editable photo frames | No tape PhotoFrame option; existing polaroid and film-strip frames are available | Put fixed tape in the supplied wallpaper, or use existing frames; exact moving tape needs approved frame styling |
| Exact collage offsets and overlaps | Theme grids and existing polaroid/collage layouts | Preserve composition within the supported layout; arbitrary per-photo overlapping/cutout effects would need additional approved work |
| Clean wallpaper at 2880×1800+ | No such asset exists in these batches | Need a clean export per theme with widget areas restored and menu bar/Dock hidden |

For exact torn/taped movable surfaces, the proposed approach is a reusable static surface/frame treatment used by current widgets, with deterministic geometry and no continuous SwiftUI animation. This would touch model/persistence, rendering, inspector options and preview QA. Estimated effort: a medium shared styling change, roughly 2–4 focused hours plus visual regression review; that estimate is provisional and no such change is authorized or implemented here. A user-exported background with fixed torn/taped decoration requires no new material or frame type.

## Required source exports

For **each of the 20 named designs**:

1. Export the full wallpaper at **at least 2880×1800**, JPEG or original layered source. Retain the artwork listed in the WALLPAPER column. Hide the menu bar, Dock, clocks, dates, calendars, media cards, checklists, editable quotes/poster words and photo-widget layers. Restore the underlying artwork where those layers were flattened. Keep decoration out of intended text areas. Supply enough surrounding composition for a 16:9 crop.
2. Export the pictures used in photo-widget slots separately. Landscape photo widgets benefit from at least 1200 pixels on their long side; portrait/square sources should preserve their original dimensions rather than be enlarged from the mockup.
3. Export torn-paper/tape frame assets separately if exact movable edges are required, or confirm use of the existing flat/polaroid frames. No AI repainting or invented replacement art is planned.

The current files can serve as comparison references, not final clean wallpaper or high-resolution photo sources. Upscaling 1586×992 changes pixel dimensions but cannot restore missing detail or remove painted UI.

## Integration plan once the assets arrive

- Keep all 20 themes, under a new family modelled on DatasetTwoThemes/StudioOriginalThemes; do not replace or rename existing themes.
- Register in WidgetTheme, ThemeLibrary metadata, ThemeCardArt, ThemeCollection and ThemeDiscovery. Expose included widgets in the existing Widgets UI. Leave carousel hero design alone.
- Use the supplied titles, original text from the user's designs where appropriate, consistent per-theme look and individually editable live widgets.
- Place clean `edit-<name>.jpg` artwork in ThemeArt; no invented placeholders and no frozen widgets embedded in wallpaper.
- Verify on a throwaway home only: zero-warning build, all tests, generated counts, cards/desktops at 1440×900 and 1920×1080, clock/calendar updates, checklist toggles, photo replacement and desktop Undo.
- Make the requested branch and small commits at verified integration steps; do not push. Rebuild the signed app. The supplied prompt's throwaway-home restriction supersedes earlier instructions to launch against the real profile.

## Changes made in this intake

- Added this report and the source/cleanup manifest under `design/provided-funky-themes/`.
- Updated HANDOFF with the intake state and outstanding assets.
- No Swift source, existing theme, user data, Keychain, credentials or environment secrets changed.
- No implementation tests, rendering or production rebuild were run because no theme code was changed and the required wallpaper assets are absent.
