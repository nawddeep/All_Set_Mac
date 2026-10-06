# Session report: 2026-09-30, theme install / preview / undo parity

Branch `claude/festive-brown-ks0f3c`. Written in a cloud session with no Swift
toolchain: **not built, not tested, not run.** First thing on the Mac:
`swift build 2>&1 | grep -c warning:` (expect 0), `swift test`, then try it (below).

## The bug
Installing a theme and previewing it then pressing Keep gave different desktops:
Install set the setup's font, corner radius and `widgetTheme`; Preview and Keep
never did. Undo put back only the widgets and their size, leaving the theme's
font, corners, theme setting and wallpaper behind.

## Done
- `AllSetCore/Themes/DesktopSnapshot.swift` (new):
  - `DesktopSnapshot` captures and restores everything a theme can change: widgets, scale, font, corners, `widgetTheme`, `widgetDesignTheme`, `showWidgets`, wallpaper config.
  - `AppSettings.adopt(_ set:)` is the one place a set's font, corners and theme ids are applied.
- `AppServices+Themes.swift`: Install (all three modes), Preview, Keep, Go Back and Undo all go through those two. Preview now puts the set on exactly as Install would, so Keep changes nothing further. Installing while a preview is showing ends the preview first.
- Behaviour changes to know about:
  - **Add Widgets** and **Restyle My Widgets** can now be undone too (before, only Replace could).
  - **Preview on Desktop** now follows the "Change the wallpaper too" toggle, like Install (before, it always changed the wallpaper).
  - The Themes page banner names the theme: "Seven is on your desktop…".
- Removed the unused `useKit` branch of `apply(_: WidgetTheme, …)`; nothing called it with `true`.
- Tests: `DesktopSnapshotTests` (2): `adopt` takes a setup's font, corners and theme; snapshot → apply a theme → restore gives back an equal snapshot.

## To check on the Mac
1. Pick a theme with a different font from yours (Seven: condensed). Preview on Desktop: the font changes now. Go Back: font, corners and wallpaper return.
2. Preview again → Keep → Undo: the desktop from before the preview returns, font and wallpaper included.
3. Apply Theme → Undo: same.
4. Turn "Change the wallpaper too" off → Preview: the wallpaper stays.
5. `-probe apply` should cost about the same (one extra array copy per install).
