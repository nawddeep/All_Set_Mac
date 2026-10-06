# Session report: 2026-09-30 → 2026-10-01, main-window redesign

Branch `claude/festive-brown-ks0f3c`. Cloud session without a Swift
toolchain: every change was built, tested, rendered and measured by CI on
`macos-26`. The redesign up to `e92ba9e` is merged into `main`; the backdrop,
heroes and probe work after it is on the branch.

## Done
- **Design system** (`Sources/AllSet/Design/`): tokens (`DS.Space`,
  `DS.Radius`, `DS.Ink`, `DS.Surface`, text roles) and shared components
  (`PageHeader`, `HeroSection`, `MediaRail`, `GlassPanel`, pill and floating
  buttons, `FilterPill`, `SearchField`, `EmptyState`, `FlowLayout`,
  `FormPage` with a header). The main window is always dark.
- **Floating navigation** replaces the sidebar: five places (Island, Desktop,
  Workspace, Tools, System; ⌘1–⌘5) in a glass capsule, each place's pages as
  pills, show/arrange widgets on the right, no title bar. `AppPage`, deep
  links and `-openPage` unchanged; new page `.desktop` (**On Your Desktop**:
  widget cards to customize or remove, with Undo).
- **Every page rebuilt** on the system: Themes (featured hero, rails), Theme
  detail, Gallery (category pills), Art (daily piece, a rail per style),
  Wallpaper (hero, source pills, rails), Monitor (a real page: tiles with
  history, heaviest apps, refresh and unit switches), Island, Workspaces,
  Snapping, Clipboard, Shelf, Mixer, TapTap, Notes, AI Screenshot and the
  settings pages.
- **Backdrop** (`WindowBackdrop`): one deep-navy canvas for the whole window
  with four soft blue glows drifting on Core Animation layers; frozen under
  Reduce Motion, a saving tier, heat, or while the window is hidden. Pages no
  longer paint over it.
- **Full-bleed heroes** on Wallpaper, Themes and Art (`BleedScrollPage`,
  `HeroSection(bleed:)`): the picture runs under the navigation and fades into
  the backdrop; the first row climbs onto it; the navigation drops its fade
  while a hero is under it.
- **Bugs found on the way:** theme previews spun forever after a memory
  purge (cards now re-ask when the purge generation changes); a filling hero
  picture pushed the title out of view; Clipboard's split view slid under the
  navigation.
- **Smoothness:** theme previews wait while anything is being scrolled. CI
  probe, warm scroll of Themes: CPU 43–61% → 9.7%, worst stall
  0.4–1.0 s → 0.14 s. Idle CPU of plain pages unchanged with the moving
  backdrop (0.5–1.4%).
- **Tools:** `-renderPages` (every page at three sizes, published to the
  `ci-screenshots` branch), `-probe scroll` and `-probe galleryparts`, and a
  CI `probe` job; CI fails on any compiler warning.

- **Balanced light and Apple's glass** (follow-up): the lens glow no longer
  reads as a hot spot (all glows alpha 0.09–0.13, bell-curve falloff). Liquid
  Glass on the floating navigation: the five places and one capsule of page
  pills, like a segmented control. Tried on every pill and button first; the
  probe showed scrolling CPU tripling, so in-page controls stay solid.

## Numbers (debug build, GPU-less CI VM)
| | Before | After |
|---|---|---|
| Themes warm scroll CPU | 43–61% | 9.7% |
| Themes warm scroll, worst stall | 431–1026 ms | 142 ms |
| Gallery scroll, worst stall | 137–453 ms | 92–146 ms |
| Blank page idle | 0.6–0.8% | 0.6% |

Frame gaps sit near 80 ms on every page on that VM (its window server), so
compare CPU and worst stalls. Real-Mac numbers not measured.

## Left as is
- First Themes visit after an install or update can still stall once (a
  preview already being drawn when scrolling starts).
- Gallery cards cost ~70 ms each to build, spread over their parts.

## To look at on the Mac
1. The backdrop's light drifting, and frozen with Reduce Motion on.
2. Island page: the preview pills and "Try it on your notch" buttons respond.
3. Themes: scroll right after opening it for the first time; then again.
4. Wallpaper → My Videos with the real library: tiles under the new hero.
