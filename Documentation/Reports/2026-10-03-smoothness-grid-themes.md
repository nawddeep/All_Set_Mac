# 2026-10-03: smoothness, grid, themes, stats (the 14-point list)

## Measured first (`-probe pageswitch`, new; ONLY=page REPEAT=n)
Main thread held after a click on a page, release build, 2nd visit:
island 327 -> 74 ms, themes 559 -> 99, gallery 850 -> 98, wallpaper 352 -> 106, desktop 27 -> 84 (12 widgets).
Cause: the page cross-fade (`.transition` opacity + scale on two whole pages) re-laid out both
pages every frame (AttributeGraph + NSHostingView.layout were 6 of 11.8 s in the profile).
Also what the user saw as the banner wallpaper "resizing" (the 0.985 scale).

## Done
1. Page switch: instant swap + `PageVeil` (Core Animation fade, render server) in `WindowBackdrop.swift`.
2. Gallery: one flat `LazyVStack` of exact-height rows (`GalleryPage.Row`, `CardGridMetrics`);
   a card is 372 pt tall. LazyVGrid/LazyHStack measure children = build them (3 of 7 s). The
   size picker is a capsule control (the system segmented control was 10 ms of a 19 ms card).
   `PageScaffold` is lazy too. `BleedScrollPage` stays eager: lazy doubled Themes scroll CPU (31 -> 51%).
   Scroll: gallery 46-51% CPU / 20 hitches -> 29-37% / 12; themes 31% -> 23-27%, 0 hitches.
3. Widget grid is now quarter cells (pitch 92): small 2x2, Extra Small (scale 0.45) 1x1.
   Dropping a widget on another of the same size swaps them (themes are packed, so nothing else could move).
4. Per-display widget size: `AppSettings.screenFits[displayName] = ScreenFit(scale, frame size)`;
   `widgetScale(for:)`; the Look & Layout slider sets all. `AppServices.refitWidgetsToScreens`
   (called by `tidyIfShapeChanged`) carries a layout to a new resolution/monitor with the tested
   `WidgetLayout.refit`; a theme installs with `fittedToScreen` + `WidgetGrid.spread` (empty cells
   slipped between widgets so wide screens have no bare sides). Not tried on a second monitor.
5. Themes banner = the theme on the desktop (`AppSettings.activeThemeSet`, in `DesktopSnapshot`),
   else the best featured; "Turn Off Theme" (`AppServices.turnOffTheme`, undoable).
6. Wallpaper: Aerial Videos stays its own tab (a first try moved it into My Videos; reverted at the user's request).
7. Tabs: Liquid Glass bar (`.regular` + faint tint) and a `glassLens()` under the selected tab;
   not yet looked at in the live window (offscreen renders don't show real glass).
8. Stats: CPU, memory (= Activity Monitor), network, disk checked against top/vm_stat/netstat: right.
   Fixed: disk rate and per-app energy averaged over the whole time nothing was watching (now kept /
   rebuilt, plus a follow-up sample 1 s after a viewer appears). Per-app lists can't include
   root-owned processes (WindowServer, kernel_task): said on the Monitor page.

## Numbers
293 tests, 0 warnings. Widgets idle at ~1% CPU each (art 3-5%); nothing to cut there.

## Open
Look at the glass tabs, Themes banner/Turn Off, swap-on-drop and a monitor switch in the live app.
The Gallery's remaining hitches are card builds (~15 ms each). "Widgets load slowly" not reproduced:
12 widgets build in 66 ms at launch.
