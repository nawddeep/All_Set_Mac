# All Set — Complete UI Specification

Every number below was read from the source or measured on a 1400 × 900 render of the current build (branch `perf-audit`, 2026-10-05). All sizes are points (pt). Where a number is derived (a formula), the formula is shown so it can be re-checked. Section 5 was updated for the approved cinematic Themes design later on 2026-10-05; other measurements describe the earlier checkpoint.

Companion to `All-Set-Design-Overview.md` (the shorter, structural version). Where the two disagree, this one is newer.

---

## 1. Product surfaces

| Surface | What it is | Size |
|---|---|---|
| Main window | Control center, always dark | Opens 1120 × 760, minimum 900 × 600, position remembered |
| Dynamic Island | Panel under the notch (virtual on notch-less screens) | Window 940 × 340; shape sizes in §10 |
| Desktop widgets | Draggable live cards on the desktop | 4 sizes, §11 |
| Menu bar item | Quick access | — |
| Live wallpaper | Video / generative art behind the desktop | Full screen |

Library counts: 54 widget kinds → 91 gallery entries in 9 categories; 57 complete themes holding 623 distinct widgets. The gallery header counts 714 widgets (91 + 623).

---

## 2. Design tokens (single source: `DesignTokens.swift`)

### Colour
| Token | Value |
|---|---|
| Canvas | rgb(0.027, 0.035, 0.059) ≈ #070910 |
| Canvas lift (top of canvas) | rgb(0.051, 0.067, 0.106) ≈ #0D111B |
| Surface · raised | white 5% |
| Surface · hover | white 8% |
| Surface · pressed | white 11% |
| Hairline border | white 8% |
| Ink · primary / secondary / tertiary | white 95% / 62% / 40% |
| Elevation shadow | black 35%, blur 18, y 8 (static only, never animated) |
| Selected control (filled pill) | white 92%, text black 88% |

The window is dark only. There is no light mode.

### Spacing
`xxs 4 · xs 8 · s 12 · m 16 · l 24 · xl 32 · xxl 48`; section gap **40**; page margin **24** below 1000 pt wide, **32** at 1000 and above.

### Corner radius
| Token | pt | Used for |
|---|---|---|
| control | 10 | text fields, small buttons, list rows |
| card | 16 | cards holding controls or text |
| media | 20 | wallpaper / theme / widget cards |
| panel | 20 | floating panels, sheets, carousel cards |
| hero | 28 | hero panels, large previews |
| capsule | full | every pill, search field, rail |

All rounded shapes use the continuous (squircle) corner style.

### Type (system font, SF Pro)
| Role | Size / weight | Tracking | Colour |
|---|---|---|---|
| Hero | 52 bold | −1.0 | primary (one per page at most) |
| Title | 28 semibold | −0.3 | primary |
| Section | 20 semibold | 0 | primary |
| Headline (card title) | 14 semibold | 0 | primary |
| Body | 13 regular | 0 | primary |
| Meta | 11 medium | 0 | secondary |
| Eyebrow | 11 semibold, uppercase | +1.2 | tertiary |

Component-specific sizes are in the component tables below.

### Motion vocabulary (`Motion.swift`)
| Name | Curve | Used for |
|---|---|---|
| quick | smooth 0.20 s | hovers, toggles, page pills |
| standard | smooth 0.30 s | content changing in place |
| gentle | smooth 0.60 s | slow cross-fades |
| responsive | spring response 0.35, damping 0.80 | lifting, picking, section switch |
| press | spring 0.25 / 0.65 | button give |
| bouncy | spring 0.40 / 0.60 | confirmations |
| reduced | ease 0.15 s | everything, when Reduce Motion is on |
| page veil | CA fade 0.9 → 0, 0.24 s ease-out | page switch (render server, not SwiftUI) |
| entrance | spring 0.5 / 0.86, rise 18 pt, scale 0.985 | content appearing |

Rule everywhere: animate opacity / transform only; no live shadow or blur on anything that moves; decorative motion pauses under Reduce Motion, Low Power, a hot Mac, or an occluded window.

---

## 3. Window frame

### Window backdrop (`WindowBackdrop`)
Linear gradient canvas-lift → canvas, top to 70% down. Over it, four radial glows drifting on Core Animation paths in a fixed 1000 × 700 space scaled to the window:

| Glow | Colour | Alpha | Diameter | Drift ellipse (centre / radii) | Period |
|---|---|---|---|---|---|
| Wide blue, top | rgb(.18,.42,1.0) | 0.13 | 900 | (360,120) / 220×70 | 46 s clockwise |
| Cyan, lower right | rgb(.10,.72,.95) | 0.10 | 760 | (760,420) / 180×120 | 58 s counter |
| Indigo, lower left | rgb(.42,.34,1.0) | 0.11 | 820 | (220,560) / 160×90 | 52 s clockwise |
| Lens | rgb(.45,.70,1.0) | 0.09 | 680 | (640,170) / 260×60 | 28 s counter |

Glow height is 72% of its diameter; bell falloff 1 / .82 / .55 / .28 / .09 / 0; each also "breathes" opacity 0.75 ↔ 1 over a quarter of its period. Frozen when paused.

### Floating navigation (`FloatingNav`) — total height 100 pt
Layout, top to bottom: 4 pt top pad · **row 1 (42)** · 8 gap · **row 2 (34)** · 12 gap below. Side padding = page margin.

| Element | Size | Detail |
|---|---|---|
| "All Set" wordmark | 15 bold, tracking −0.2 | leading edge of row 1 |
| Section capsule (row 1, centred) | height 42 = 4 pad + 34 buttons + 4 pad; radius 22 | Liquid-Glass (macOS 26) tint white 5%, lit rim 1.0 |
| Section button | height 34, horizontal pad 14, 13 semibold, icon 12 semibold + 6 gap | icon drops first when narrow; gap between buttons 2; ⌘1–⌘5 |
| Selected section | glass "lens" capsule, tint white 24%, interactive | slides via matched geometry |
| Desktop switches (row 1, trailing) | capsule radius 21, two 34 × 34 circle buttons, gap 2 | eye (show/hide widgets), hand (arrange); "on" = white 92% fill, black glyph |
| Page capsule (row 2, centred) | height 34 = 3 pad + 28 pill + 3 pad; radius 18; rim 0.65 | scrolls horizontally if the pills don't fit |
| Page pill | height 28, horizontal pad 12, 12 medium, icon 11 semibold + 6 gap | selected = glass lens |
| Count badge | 10 bold monospaced digits, min 16 × 16, pad 5 | white 20% (selected) / hover fill |
| Scrim behind nav | solid canvas-lift to row 2's lower edge, then fades to clear over the 12 pt gap | removed (opacity 0) when a page puts media under the nav |

Sections and their pages:

| Section | Pages (pill order) | Opens on |
|---|---|---|
| Island | Dynamic Island, Live Activities | Dynamic Island |
| Desktop | Themes, Widgets, Favorites, Wallpaper, Look & Layout, Wallpaper Options, On Your Desktop (count) | Themes |
| Workspace | Window Snapping, Workspaces | Window Snapping |
| Tools | Clipboard (count), Shelf (count), Sound Mixer, TapTap, AI Screenshot, Notes (open count) | Clipboard |
| System | Monitor, Lid Plane, General, About | Monitor |

Each section remembers the last page you were on. Detail pages (a theme set, a widget) keep their parent pill lit.

### Other window furniture
- Removed-widget undo bar: glass capsule radius 22, height 44, left pad 16, right pad 5, auto-hides after 8 s.
- Error banner (layout couldn't be saved): orange 22% fill, radius 10, pad 16 × 8.
- Page switch: pages swap instantly under the veil; below-the-fold content builds one frame later (`Deferred`).

---

## 4. Shared components

| Component | Spec |
|---|---|
| **GlassPanel** | Radius 20 (default) · padding 24 (default). macOS 26: Liquid Glass regular + white 5% tint; earlier: ultra-thin material + white 4% fill. Rim: 1 pt stroke gradient top-left → bottom-right white 42% @0, 10% @0.35, 4% @0.65, 18% @1, plus a top sheen white 7% → clear over the upper half. Never used on scrolling content. |
| **Pill button** (`.pill`) | Height 34, horizontal pad 16, 13 semibold, capsule. Fill hover-8% → 13% on hover → 11% pressed. Press scale 0.96. Disabled opacity 0.45. |
| **Prominent pill** | Same, fill white 92% (100% hover, 80% pressed), text black 88%. One primary action per area. |
| **Floating button** | Circle, default 34 (arrows 36, favourite 30), glyph 13 semibold; fill black 42% (60% pressed), hairline ring; press scale 0.92. |
| **Filter pill** | Height 28, horizontal pad 12, 12 medium, optional 11 icon; idle fill raised 5%, selected white 92% with black 88% text. |
| **Search field** | Height 34, horizontal pad 12, 13 regular, capsule, fill raised 5% + hairline; magnifier tertiary; clear button appears with text. |
| **Section header** | Title 20 semibold, optional meta subtitle 11 (gap 4), "See All" 11 medium secondary at trailing edge. |
| **Page header** | Optional eyebrow, title 28, body subtitle; actions on the trailing edge, bottom-aligned; gap 8 between lines. |
| **Media card** | Radius 20, hairline ring (selected: 2 pt white), hover scale 1.02, shadow elevation, optional title (headline) + meta below (gap 8, inset 4). |
| **Media rail** | Horizontal scroll, lazy, card gap 16, vertical pad 8, snaps to card edges (view-aligned). Default card width 260. |
| **Preview canvas** | Height 360 default, radius 28, raised fill + hairline. |
| **Hero section (bleed)** | Media edge to edge under the nav; top scrim black 32% → clear over 1.8 × nav height (max 50%); left scrim black 55% → clear to centre; vertical mask solid to 50%, 60% at 75%, clear at 100%; words bottom-left, max width 620, left pad = margin, bottom pad = overlap 48 + 32. Height = nav inset + visible (62% of viewport, clamped 320–560). |
| **Hero section (card)** | Height 420, radius 28, hairline, words padded 32, bottom/left scrims black 78% → 25% → clear. |
| **Empty state** | 34 light glyph (tertiary), headline, body, optional pill; max width 360; vertical pad 48. |
| **Flow layout** | Wrapping rows; spacing 12 (default), line spacing 12. |
| **Card grid metrics** | columns = floor((width + gap) / (min + gap)); card width = floor((width − gaps) / columns). |
| **Form page** | Grouped macOS form, hidden grey backdrop, header on the canvas outside the rounded boxes. |

---

## 5. Themes page — approved cinematic design, 2026-10-05

Reference: `design/themes-concepts/2026-10-05-cinematic-reference/themes-preview.png`. Native captures: `build/review/selected-design/`, including the actual signed Dock app. Implementation: `Documentation/Reports/2026-10-05-themes-cinematic-design.md`; latest toolbar/cache refinement and measurements: `Documentation/Reports/2026-10-05-themes-toolbar-smoothness.md`. Other sections retain their earlier measurements unless stated otherwise.

### Structure

The existing navigation capsules stay above a fixed 48 pt `ThemesFilterBar`, with one 12 pt-radius surface and a faint 8%-white rim. Inactive categories are plain 12 pt medium labels with 4 pt spacing; the selected label has a 30 pt-high white pill. The rail has no separate capsule or outline. Search is integrated into the same surface after an 18 pt divider, 164 pt wide below 1000 pt of available width and 190 pt otherwise. The focused search subtly strengthens the toolbar border.

Categories scroll horizontally when needed, with a 16 pt edge fade. Below 1220 pt available width an accessible All theme categories menu gives direct access to every filter. External category changes also bring the selected label into view. Reduced Motion uses a fade.

The toolbar stays outside the vertical scroll view. The content uses one eager vertical stack with lazy horizontal rails; there is no pinned-header LazyVStack. Category changes and entering/leaving search reset the scroll container to its result start, while each typed character preserves the search field and its focus.

All with empty search shows the carousel, desktop status banners, Trending themes, Moodboards shortcuts and deferred collection shelves. Other selections and search show a results count, include-wallpaper switch and matching-theme grid. Search respects the selected collection.

### Spotlight geometry

`ThemeCarouselLayout` is the source of these formulas. Given viewport W×H and horizontal margin M:

- Panel width = max(W − 2M, 0).
- Target height = min(max(0.66H, 290), 540).
- Card height = max(min(target − 128, panel width × 0.34 ÷ (1136/768)), 0).
- Center aspect = 1136/768; neighbour aspect = 3/4. During movement the aspect interpolates by max(1 − |distance|, 0).
- Panel height = card height + 128 pt; two neighbours per side, 12 pt gaps, computed using turned/scaled half widths to avoid overlap.
- Depth at distance d: scale = max(1 − 0.09min(|d|,3),0.73); shade = min(0.1|d|,0.35); tilt = ±min(12|d|,20) degrees; vertical dip = 8min(|d|,3) pt. Reduce Motion removes tilt and uses a short dissolve.

The center displays a cached complete desktop. Neighbours display cached curated portraits; text overlays show name and widget count. Every card has an accessible favorite control. The selected card has a 1.5 pt cyan-to-secondary-accent border and a Featured/On your desktop badge. Card-only Apply buttons are removed.

Static elliptical floor pools and a faint flipped snapshot add reflected light. They do not animate blur or continuously rebuild widgets. Cached atmosphere follows the chosen theme. Snapshot consumers retain their request until task cancellation; changing variants releases the old request. Each cached preview is separately observable, so an unrelated image arrival does not invalidate the gallery. The hero prepares only its two adjacent desktop previews ahead of movement. The carousel takes keyboard focus after interaction, preserving typing when search is cleared.

### Actions and browsing

Seven pagination dots select the nearest carousel slot. The selected name is 26 pt, or 22 pt for card heights below 230. Apply/Turn Off Theme, Preview on Desktop, Favorite and the options menu sit below it. Options contain Include wallpaper and View theme details. Arrows, continuous drags, horizontal wheel input and arrow keys loop through the real library.

Trending uses complete cached desktop collages with names/counts and always visible hearts. Rail cards use five columns at available widths ≥1200, four at ≥900, otherwise three, with a minimum card width of 190. Horizontal lazy rows have arrows and See all. Moodboards has five 92 pt-high shortcuts: Minimal, Dark, Colorful, Moodboards and Developer, each showing actual counts.

Midnight Aurora is a real 12-widget theme backed by an original offline JPEG. Its complete desktop anchors the selected composition. Existing themes and user-local art remain supported.

## 6. Widget Gallery page (Desktop › Widgets)

Measured at 1400 × 900.

| Element | Spec |
|---|---|
| Header | Eyebrow "714 WIDGETS" (11 semibold, tracking 1.2) · title "Widget Gallery" 28 semibold · subtitle 13 secondary; search field top-right, width 280, 34 high |
| Category row | Filter pills (28 high, gap 8): All, From Themes, Time, Productivity, System, Developer, Lifestyle, Aesthetic, Football, Music, Mystic |
| Section | Title 20 + count meta, "See All" trailing |
| Grid | Cards min 300, gap 24 → 4 columns at 1400 (card width floor((1336 − 72) ÷ 4) = **316**) |
| Card | Fixed height **372**, radius 20, hairline + elevation; top: live widget preview on a gradient tile (fit 250 × 190 max); title row (kind icon + headline) with S / M / L size chips; one-line summary (meta); material chips row (scrolls); full-width "Add to Desktop" prominent pill (34 high) |
| Material chips | Photo, Solid, Frosted, Outline, Mesh, Apple Minimal, Liquid Glass, Dark Glass … |

Rows are built in explicit chunks so the page scrolls without per-card layout cost.

---

## 7. Wallpaper page (Desktop › Wallpaper)

| Element | Spec |
|---|---|
| Hero | Bleed hero: height = 133 + visible (62% of 767 = 475, clamp 320–560) = 608; the current wallpaper live, eyebrow "ON YOUR DESKTOP", hero title 52 bold, meta row (e.g. Abstract · Live · 1440p · 8.2 MB), actions "Turn Off" / "Options…" (pills 34 high), then source filter pills (Aerial Videos, Art, My Videos) |
| Section | "Aerial Videos" 20 + one-line description (13 secondary); quality menu (e.g. "4K, about 320 MB each") and download menu, right-aligned, 34 high |
| Category pills | All, Landscapes, Cities, Underwater, Space |
| Rails | Aerial cards 300 wide (16:9), my videos 280, art 180; "See All" |
| Grids | Adaptive: 260 min (videos, gap 16), 220 min (14 gap), 150 min (12 gap), 140 min (8 gap) |

---

## 8. Other Desktop pages

Only layout numbers that were read from the source are listed. Unmeasured items are marked.

| Page | Layout |
|---|---|
| Favorites | Adaptive grid, min 280, gap 16, row gap 24 |
| Look & Layout | Form page (grouped form on the canvas) — inner control sizes not measured |
| Wallpaper Options | Form page — inner control sizes not measured |
| On Your Desktop | Adaptive grid, min 240, gap 24; widget preview fit 200 × 140 in a 170 tall tile |
| Theme detail | Preview canvas 1136:768 (568 × 384 thumbnail), content max width 1080 |
| Widget customisation | Live preview fit 360 × 360 beside the options editor |

---

## 9. Workspace, Tools and System pages

Built from the shared components above (page margin 24/32, section gap 40; `GlassPanel` only for floating chrome). Per-page layout numbers were **not** measured for this document; the pages are:

Window Snapping · Workspaces · Clipboard (+ picker overlay) · Shelf · Sound Mixer · TapTap · AI Screenshot · Notes · Monitor · Lid Plane · General · About.

---

## 10. Dynamic Island

Always at the top of the screen under the camera notch (or a virtual one). Host window 940 × 340 (fits the largest state plus its shadow).

| State | Size |
|---|---|
| Closed | The notch's own size |
| Hover | notch + 14 wide, + 4 tall |
| Live activity (closed) | notch width + 2 × side, notch height + caption |
| Expanded · Home | 640 × 200 |
| Expanded · Tray | 700 × 210 |
| Expanded · Mixer | 700 × 240 |
| Expanded · Notes | 640 × 250 |
| Expanded · System | 860 × 300 |

Live activity side widths: now playing 42, volume 70, power / low battery 64, audio device 46 (+ 26 caption row), knock 48.

Shape radii: closed top 6, bottom 10 (16 with a caption); expanded top 14, bottom 28. Content inset: width − 44, height − notch height − 26. Tabs: Home, Tray, Mixer, Notes, System, with Core Animation open / close / tab-switch motion; Reduce Motion swaps springs for a short dissolve.

---

## 11. Desktop widgets

| Size | Dimensions (pt) | Grid |
|---|---|---|
| Small | 168 × 168 | 2 × 2 |
| Medium | 352 × 168 | 4 × 2 |
| Large | 352 × 352 | 4 × 4 |
| Extra large | 720 × 352 | 8 × 4 |

Gap between widgets 16, edge margin 8, snap grid 8. A widget can also be scaled and stretched within clamped ranges. Materials: Glass, Dark, Light, Tinted, Paper, Frosted, Clear, Outline, Art, Photo, Mesh. 15 design skins; 57 theme looks.

Categories (gallery entries): Time 9, Productivity 9, System 12, Developer 8, Lifestyle 8, Aesthetic 22, Football 11, Music 6, Mystic 6.

---

## 12. Accessibility and performance contract

- Reduce Motion: carousel flattens (no tilt), slides become 0.15 s dissolves, backdrop glows freeze, entrances become fades.
- Low Power Mode or a hot Mac: no card lift, no card glow, shorter snap, atmosphere fades 0.15 s.
- Occluded window: backdrop animation pauses.
- Text: primary 95%, secondary 62% and tertiary 40% white on near-black canvas; tertiary is for eyebrows and hints only.
- Every icon-only control has an accessibility label; selected states carry the selected trait.
- Navigation shortcuts ⌘1 – ⌘5; carousel ← →.

### Measured performance (this Mac, M4 MacBook Air, probes in `-probe`)
| Check | Result |
|---|---|
| Tests | 313 passing in 85 suites, 0 warnings |
| Carousel probe | 8 of 8 backdrops ready before the page is seen, **0 blurs while the carousel moves**, atmosphere in sync, routing / landing / looping checks pass in both motion modes |
| Themes scroll CPU (latest toolbar refinement) | Mean **43.1%** vs 47.2% before in interleaved runs; p95 18.2–20.2 ms vs 20.6–25.1; 0 >33 ms hitches in both. See `2026-10-05-themes-toolbar-smoothness.md` for shared-system limits. |
| Themes page switch (main-thread hold, warm) | **96–137 ms** now vs **84–123 ms** old |
| Earlier phases (before the atmosphere) | scroll ≈ equal; switch ≈ 113 vs ≈ 95 ms |

Status: the atmosphere costs about 5 points of scroll CPU. A test flattening it into one layer has not been run; the temporary code for it was removed.

---

## 13. Rules any change must keep
1. Dark only; one backdrop for the whole window; pages never paint their own.
2. No brand logos, album art, trademarks or promo photos; themes are original; the user's player photos stay on their Mac and out of the repo.
3. No glow stronger than the reference, no rainbow neon, no pulsing or floating cards, no per-card grain or live blur.
4. Maximum two accent hues per theme; glow never over text.
5. Page switches must not get slower; scrolling must not drop frames.
6. Removed on purpose, do not return: Collections, Art, Home pages.
7. Navigation stays five places with pages beneath; a new page is added to both the section mapping and the pill list.
