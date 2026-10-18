# How All Set themes are made

## What a theme is
A theme is a whole desktop: widgets on a grid, a look and a wallpaper, applied together. Each widget stays fully editable after install.

- `WidgetTheme` holds the look and the widget layout (the "kit").
- `ThemeSet` is the catalogue entry: name, tagline, philosophy, inspiration, research notes, collections, tags, date, ranking and lighting.
- `DesignTheme` (15 of them) is a surface style only, with no layout.

## Families (111)
| Family | # | Character |
|---|---|---|
| Moodboards | 14 | B&W photo walls, script words, chrome stickers, packed |
| Football & Music | 22 | Built on moods; all players, clubs and fixtures invented |
| Colour & Light | 8 | Bright, warm, pastel |
| Core setups | 14 | Midnight Aurora, Pink Latte, Dark Academia… |
| Studio Originals | 25 | Each built around a commissioned original wallpaper |
| Desktop Edit | 25 | Original compositions from studied reference desktops |
| Monochrome Edit | 3 | Sparse, editorial, mostly B&W |

## The look
| Field | Values |
|---|---|
| `material` | glass, dark, light, tinted, paper, photo |
| `card` / `ink` / `accent` | colours for carded widgets |
| `wallpaperInk` / `wallpaperAccent` | colours for bare widgets, chosen against the wallpaper so bare clocks and words stay readable |
| `font` | standard, rounded, serif, monospaced, condensed |
| `cornerRadius` | 5–7 editorial, 20–24 soft |
| `textStyle` | classic, modern, bold, elegant, script, handwritten, typewriter, poster, editorial |
| `clockFace` | digital, analog, stacked, flip, minimal |
| `palette` | colours generative wallpapers and art widgets |
| `photoFilter` | none, mono, noir, warm, cool, vintage, fade, dreamy, duotone; one per theme makes mixed photos one set |
| Decoration | sticker (shape, finish, colour), note colour, icon |

`styled()` applies the look one widget kind at a time:
- **Self-painting widgets keep their own art:** jersey, player card, vinyl, polaroids, moon, ticket, scoreboard.
- **Word art and cassettes** take `wallpaperAccent`.
- **Ambient widgets** take the palette.
- **Everything else** takes the material, the colours and the palette. Quotes also take `textStyle` and clocks take `clockFace`.

## Layout
A kit is a list of `KitItem(kind, size, column, row, configure)`.

- **Grid:** each cell is 168 pt, with 16 pt gaps and an 8 pt margin.
- **Sizes:** small 1×1, medium 2×1, large 2×2, extra large 4×2.
- **Usual extent:** 6 columns × 4 rows.

Each family has its own pattern:
1. **Packed wall** (Moodboards, Football & Music). Every cell is used, with photos alternating with the clock, Now Playing, calendar, a script word and a sticker.
2. **Corner clusters** (Desktop Edit). The wallpaper is the subject, and the widgets keep to the corners.
3. **Margin column** (Monochrome Edit). A narrow column of utility widgets, one framed photo and an empty centre left free for work. Items are dropped on small screens.
4. **One template per wallpaper** (Studio Originals). Each layout is chosen to fit where its artwork is empty.

Helpers keep kits readable:
- `Kit.bare` removes the card.
- `Kit.photo(n)` fills photo slot *n*.
- `collage`, `prints`, `words`, `wordArt`, `list`, `neon` and `player` set up common widgets.
- `both` combines two helpers.

The Studio, Desktop Edit and Monochrome families are built with a `make(...)` factory that enforces house rules:
- Bare colours are the same as card colours.
- Note colour and sticker finish follow from whether the theme is dark.
- Every widget is forced to the theme's font and corner radius.
- Studio themes also clear card backgrounds and turn off animation and neon flicker.

## Wallpaper and photos
The wallpaper comes from one of three sources:
- **Generative art,** drawn on the Mac: 943 style × palette combinations, with no download.
- **Bundled original art.**
- **CC0 library photos.**

The photo pool comes from collections that match the mood, such as "Stadium Nights" and "Mist & Forest". `ThemeSet.personalized` fills the photo slots with the user's own photos, and the theme's filter still applies.

## The words
- **Title:** two or three evocative words, e.g. "Floodlight Gold".
- **Tagline:** materials and mood in one sentence.
- **Philosophy:** where the eye goes.
- **Inspiration:** mood only.
- **`ThemeResearch`:** era, sources, colour, type, motion, texture, photography, and what was referenced versus original.
- **Tags:** search words.
- **In-widget words:** written per theme ("DREAM BIG").

## Originality rules
- No real people, clubs, nations, crests, kits, album art or lyrics, including in tags. `RealPeopleDenylistTests` enforces this.
- Players are archetypes, e.g. "CAPTAIN #14, Red & Green".
- Reference desktops are studied, never copied. Every installed pixel is native or bundled art.
- Photos are CC0, listed in `third-party/licensed-photos.md`.

## Lighting
The selected theme lights its card edge, its glow and the haze behind it. This light is a `ThemeAccent`: a primary colour, a secondary colour and a glow strength from 0.6 to 1.

1. **Chosen by hand** for the leading themes, because averaging a picture gives mud, or grey on B&W themes.
2. **Otherwise**, the first colour with real colour in it (value > 0.3, saturation ≥ 0.18), checked in this order:
   1. the theme's accent;
   2. the wallpaper accent;
   3. the design theme's accent;
   4. the wallpaper's colour.

   The secondary colour is another hue at least 0.06 away, or a paler primary. Glow is 0.9 on dark themes and 0.65 on light ones.
3. **Fallback:** warm gold.

## Carousel card (`ThemeCardArt`)
A 3:4 portrait built from the theme's real widgets on a 552×736 canvas:
- **Middle:** one large widget.
- **Top:** word art as the title.
- **Sides:** up to four small widgets, shown whole.
- **Bottom:** left clear for the name and buttons.

When picks are automatic, the middle widget is the first large one, otherwise the first medium one. Small widgets of different kinds are chosen first, so the card shows the theme's range. Hand-picked cards also crop the wallpaper with zoom and focus.

Three renders exist for each theme:
- **desktop**, for the rails and the detail page;
- **card**;
- **backdrop**, a pre-blurred 384×240 picture.

## The Themes page
1. **Filter bar:** search plus 16 filters (Recommended, New, Dark, Favorites…).
2. **Hero carousel.**
   - **Card shapes:** the selected theme is a landscape desktop and its neighbours are 3:4 portraits. Each card's shape follows its distance from the centre.
   - **Each step away:** −9% scale, dimmer, 12° tilt, 8 pt lower. Cards more than two places away fade out.
   - **Atmosphere:** the theme's light over navy, with its blurred wallpaper as haze. Changes are opacity-only cross-fades.
   - **Glow:** one pre-drawn image, tinted.
   - **Reduce Motion** switches to fades. **Low Power Mode** drops the lift and glow.
3. **Rails and shelves:** the Recommended rail, then Moodboards, then the collection shelves.
4. **Detail page:** preview, philosophy, included widgets and the install choices.

## Install, preview, undo
- **Install modes:**
  - **Replace** swaps out the current widgets.
  - **Add** puts the theme's widgets in free spots.
  - **Restyle** changes the look only.

  The wallpaper is optional. With more than one monitor, the app asks which display gets the widgets.
- **Preview:** saves the current desktop to a journal first. A crash restores it at the next launch.
- **Undo:** a toast after each change. **Restore Previous Desktop** works after relaunch.
- **Usage counts:** stored locally only. They feed Recommended and Top Picks.

## Principles
1. A theme is a composition: wallpaper, layout, look and words together.
2. The wallpaper decides where widgets go.
3. Separate colours for cards and for bare words.
4. One filter unifies the photos.
5. Factories keep each family consistent.
6. Everything stays editable and original.
7. Performance first: pre-rendered images, opacity-only fades.
