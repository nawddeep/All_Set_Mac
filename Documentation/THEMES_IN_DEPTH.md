# Themes in depth: everything else

Companion to `HOW_THEMES_ARE_MADE.md`; covers what it leaves out.

## Collections (25)
- **Moods:** Featured, Moodboards, Night, Dreamy, Retro, Pop, Indie, Rock, Hip-Hop, R&B, Cinematic, Cosmic, Minimal, Luxury, Neon, Ambient, Japanese Zen, Designer, Developer, Colour & Light.
- **Fandom:** Football, Music Icons.
- **Families:** Desktop Edit, Studio Originals, Monochrome Edit.

A theme can be in several collections. Its collections come from its family's `make(...)` call, or from the per-id switch in `ThemeLibrary`. Every collection is a shelf on the page. The "Monochrome Edit" collection is called `datasetTwo` in code, and "Moodboards" is `artistWorlds`.

## Ranking
With no usage at all, the library's order comes from two values set in `ThemeLibrary.setups`:

| Family | `added` date | `baseline` |
|---|---|---|
| Monochrome Edit | 2026-10-08 | 97 |
| Studio Originals | 2026-10-08 | 96 |
| Desktop Edit | 2026-10-08 | 94 |
| Midnight Aurora | 2026-10-05 | 98 |
| Moodboards | 2026-09-25 | 90 minus the theme's position |
| Fandom | 2026-09-25 | the spotlight value, else 88 minus position |
| Colour & Light | 2026-09-30 | 70 |
| Core | 2026-09-24 | 55 |

The spotlight values are Floodlight Gold 97, Rain Derby 96.5, Americana 96, Sky Playmaker 93 and Acid Moss 92.

Usage is stored only on this Mac, by `ThemeStats`. It records installs, applies, previews, favourites and the last time each theme was used.

- **Popularity** (Top Picks, Featured order) = baseline + 3 × installs + applies + 10 if favourited.
- **Trending** (Recommended, top 12) = 0.5 × baseline + activity × (0.5 + recency) + 10 × recency + season.
  - activity = 3 × installs + 2 × applies + 0.5 × previews + 5 if favourited.
  - recency falls from 1 to 0 over the 14 days after the theme was last used.
  - season adds 20 when the current month is one of the theme's `seasons`.
- **New** lists themes added in the last 45 days, newest first.
- **Dark** uses `isDark`: Desktop Edit themes declare it; for others, a photo or video wallpaper counts as dark, and an art wallpaper counts as dark when its palette isn't light.
- **Colorful** means a vivid accent, or an art wallpaper with a saturated palette.

## Search
`ThemeLibrary.search` first ranks themes whose name matches the query. It then adds every theme whose `searchText` contains all the typed words. `searchText` covers the name, tagline, description, collections, tags and the kinds of widget the theme includes. That is why "pink", "developer" and "calendar" all find themes.

## Old theme ids
`ThemeLibrary.set(id)` passes every id through `LegacyIdentifiers.theme` first. The same mapping is applied to the keys of the saved theme photos. Renamed themes, including the football and music themes that used to be named after people, therefore still load from old desktops, backups and links. The old names are never shown.

## Design themes (15)
These change only how widgets look and add no layout:

> Apple Minimal, Liquid Glass, Dark Glass, Aurora, AMOLED, Cyberpunk, Terminal, Retro Macintosh, Japanese Zen, Editorial, Brutalist, Neumorphism, Paper, Monochrome, Dynamic Wallpaper.

Each one sets the following:

- **`surface`:** how the card is drawn, from 16 styles. A few examples:
  - Liquid Glass: blurred with a specular edge.
  - Terminal: phosphor text with scan lines.
  - Retro Macintosh: a striped title bar.
  - Brutalist: a hard offset shadow and square corners.
  - Glow: lit from inside by the accent.
  - Chrome: brushed metal or gold foil.
- **Light and dark palettes.** A theme that only works one way leaves the other palette out.
- **`typography`:** font, weight of big numbers, weight of titles, whether small labels are in capitals, and letter spacing.
- **`accentSource`:** the theme's own colour, a subtle colour taken from the wallpaper, or the system accent.
- **Shadow, corner radius,** and an optional live wallpaper that suits it.
- **`motion`:** how the theme moves. Each surface has a default; a theme can override it.

| Motion | Default for |
|---|---|
| Energetic | Terminal, Cyber, Brutalist |
| Still | Zen, Retro |
| Orbital | Aurora |
| Cinematic | Editorial, Chrome |
| Playful | Neumorphic, Gradient |
| Calm | everything else |

Reduce Motion always overrides the theme's motion.

## Theme detail page
`ThemesPage+ThemeDetailPage.swift` shows:

- a live preview of the desktop and a list of the widgets it includes, with their sizes;
- the colours as hex values;
- a type sample: "12:47 / Friday, 25 September / Up next", set in the theme's weights and label style;
- a motion demo: a number changing and a dot arriving, moving the way the theme moves;
- the accent setting. Automatic tints only highlights toward the wallpaper's colour, never the whole widget;
- references, with this disclaimer: *"An original theme inspired by public visual characteristics of a genre and era. Not affiliated with or endorsed by any artist; no logos, album art, photography or trademarks are used."*;
- whether the theme has picture slots you can fill with your own photos;
- the install choices, with this note: "Installs N widgets [and the wallpaper]. You can undo it from the Themes page."

## What happens on install
`themeWidgets()` runs these steps in order:

1. **Lay out.** The kit is placed on an unbounded canvas.
2. **Personalise.** The user's photos go into the picture slots.
3. **Fit.** The widgets are fitted to the screen's visible area.
4. **Arrange.** They are snapped to the grid.
5. **Spread.** They are spread to the screen's edges, so a wide display doesn't leave empty sides.

**More than one display.** The app asks "On this Mac" or "On <monitor>", listing the built-in display first. Only that display's widgets are replaced; the other display keeps its own.

**`settings.adopt(set)`** saves which theme is on, its font, its corner radius and its design theme, and turns widgets on.

**Turn Off Theme** clears the widgets and resets the look to that of a fresh install. It can be undone (`DesktopUndo.turnedOff`).

## Your own photos
`ThemePhotos` keeps the photos you choose for each theme in `theme-photos.json`. They fill the theme's picture slots in layout order:

- photos, tapes, prints, player portraits and lock screens;
- player cards take the first photos, so put your best portrait first;
- if there are more slots than photos, the photos are used again from the start.

## Carousel numbers
Middle card 1136:768, height 66% of the window (290–540 pt); side cards 3:4; 12 pt gaps. Each step away: scale −9% (min 73%), dim +10% (max 35%), tilt 12° (max 20°), 8 pt lower; gone beyond two steps. Settle 0.45 s, atmosphere 0.7 s, text 0.18 s. The category pill slides (fades with Reduce Motion).

## Tests
`ThemeLibraryTests`, the three family tests (Reference, StudioOriginal, DatasetTwo), `ThemeWidgetCatalogTests`, `ThemeCarouselLayoutTests`, `ThemesAndSearchTests`, `RealPeopleDenylistTests` and `ContentCountsTests` (keeps the README count right).

## Adding a theme
1. Write a `WidgetTheme` (or a family `make(...)` entry): id, title, tagline, both colour pairs, font, radius, text style, clock, palette, filter, sticker, wallpaper, photo pool, 6×4 kit.
2. Add it to the family list; older families also need collections and tags in `ThemeLibrary`.
3. Optional: a light in `ThemeLibrary.accents`, a card in `ThemeCardArt.curated`.
4. No real names; CC0 or original images only.
5. `swift test`, `UPDATE_COUNTS=1 swift test --filter ContentCountsTests`, render with `-renderPages` on a throwaway home.
6. Renamed or removed: map the old id in `LegacyIdentifiers`.

## Performance (2026-10-18)
Met: gallery card build 11.9 ms. Not met: Themes scroll CPU 41–49% (target 20%); page switch 75–140 ms (target <100); CI idle CPU 25.4% (limit 2.75%), not yet investigated.
