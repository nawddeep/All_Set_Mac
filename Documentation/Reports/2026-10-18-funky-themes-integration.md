# Supplied Funky Themes: integration, 18 October 2026

The user supplied 20 desktop designs (two batch folders in `themes_update`, ten PNGs each). The original files are unchanged. All 20 are installable themes in the **Funky Themes** collection (131 themes in the catalogue).

## How each theme is built
- **Wallpaper: the design itself.** Each supplied PNG is a flattened 1586×992 screenshot: artwork plus a menu bar, a Dock and painted clock, calendar, music and notes cards. `scripts/prepare-funky-themes.py` keeps all of the artwork: collage, photos, lettering, stickers, tape and torn paper. It does three things to the rest:
  - **Painted cards:** paints over the inside of each one with a plane fitted to the card's own colour plus matching grain. The card's outline, shadow and torn edge stay.
  - **Menu bar:** fills its strip from the artwork just below it. The real menu bar covers that strip anyway.
  - **Dock:** inpaints the painted Dock from its surroundings. The real Dock usually covers it.

  The result is upscaled to 2880×1800.
- **Live widgets on the painted cards.** `design/provided-funky-themes/layout.json` (batches 1-2) and `layout-<n>.json` (batch n) record each painted card's inside, in source pixels, with its widget kind, size and ink. The script turns this into `Sources/AllSetCore/Themes/FunkyLayouts.swift`, and the look of each theme added after the first twenty (`meta`: colours, font, text style, collections, radius, glow) into `FunkyThemesMore.swift`.
  - Each widget goes where its card is and takes the widget's own scale (the same as a corner-drag resize) to fill it.
  - Stretch is kept within ±8%, because the desktop draws stretch by squeezing pixels.
  - Widgets are bare, so they sit on the painted card instead of a card of their own, in the ink that reads on it.
- **On screen** (`FunkyThemes.fitted`), the wallpaper fills the screen, centred and cropped. The widgets use the same scale and origin, so each stays on its card on any size of display. On a 16:9 screen the picture loses a little top and bottom, and a widget on that edge moves in only as far as it needs to stay below the menu bar.
- Previews (`ThemeComposition`) and the render harness now draw a widget's own scale, as the desktop does.

To change a layout, edit the JSON and run the script with the folder holding the two batch folders:
`python scripts/prepare-funky-themes.py <folder> [--preview <dir>]`

## Verified
- `swift build`: no warnings. `swift test`: 473 passed after every batch.
  - `FunkyThemeTests` checks that every widget's centre lands on its card within 1 pt at 1440×900, 1512×982, 1920×1080 and 2560×1600. It also checks that no widgets overlap, the wallpapers are 2880×1800, and the themes carry no photo slots or remote images.
  - The general grid-layout tests skip these themes, which are traced rather than gridded.
- Counts were regenerated after every batch: 181 themes, 1,428 widgets from themes.
- The 70 wallpapers are 45 MB (JPEG quality 80); at 88 they were 59 MB.
- `scripts/check-repo-hygiene.sh` and `scripts/check-localization.sh` pass.
- All 20 desktops were rendered at 1440×900 and 1920×1080 on a throwaway `CFFIXED_USER_HOME` and compared with the supplied designs.

## Limits
- **Detail:** the artwork has the detail of the 1586×992 originals. Upscaling to 2880×1800 doesn't add any. Original layered files at full size would make every theme sharper, and the script can take them by changing the source size in one place.
- **Under the Dock:** the inpainted Dock area is smooth rather than detailed. It's only seen with the Dock hidden.
- **Card insides:** the cleared insides are smooth, with the card's colour and grain, where a few designs had a photo or texture inside the card (Peach Film Bloom's and Blue Haze Diary's clocks, the glass cards over lace in Lace City Noir).
- **Your own content:** Now Playing shows what is actually playing, and Notes shows the person's own notes. The design's sample track names and to-do items aren't data a theme can set. Previews with no music or notes show the app's standard samples.
- **Clean Up:** Arrange's Clean Up snaps widgets to the grid, which moves them off their cards. Reinstalling the theme puts them back.
- **Photos:** the photos in these designs are part of the wallpaper, not swappable photo widgets.
- **Batch 3-7 specifics:** every design was read against a coordinate grid; its widget cards were measured by eye, so a card can be a few pixels off. `Now Playing` only comes in small or medium, so on tall cards it fills the width and leaves some of the card empty. Painted extras that aren't one of the four widgets (an "Archive" strip, a playlist, a photo-count card) stay in the wallpaper as art with their sample text.
- **Menu bar:** now inpainted from the artwork around it. The Dock is inpainted too, and shows as a smooth smear only where the real Dock is hidden.
- **Glow:** black-and-white designs carry a hand-picked glow colour (`meta.glow`), as their accents are grey.
