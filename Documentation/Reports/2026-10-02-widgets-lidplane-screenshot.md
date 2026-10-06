# 2026-10-02: widgets, Lid Plane, AI Screenshot shortcut

## Done (all verified, committed locally, not pushed)
- `4dec6f5` Widget snap grid (`WidgetGrid`), drag to a free slot with a live overlay, gallery
  drag-to-desktop, right-click menu (Edit, Size, Clean Up, Arrange, Remove). Every theme keeps
  its shape on the grid (test over all 57).
- `5cb9353` From Themes gallery (623 widgets); per-widget font, letters, corners, renamed
  built-in words (`WidgetWord`, listed live from the preview) and a caption below.
- `0626efc` Lid Plane (Jhey, GPL-3.0-or-later) as System → Lid Plane; notices in
  `Documentation/third-party/`. Also: Keychain delete-token read moved from launch to use.
- `bf59f1f` AI Screenshot on ⌘⇧5 / ⌃⌥⌘5; macOS's own shortcut (symbolic hotkey 184) switched off
  and restored on quit, with a crash-safe marker.

## Numbers
263 tests (was 239), 0 warnings. Gallery scroll before/after the new rails: no change.

## Open
Steps 4-7 of the user's list (Mac analysis, choppiness, window UI toward the Wallspace
reference, Island Notes alarms). Unverified by a person: gallery drop, direct widget drag,
live Lid Plane capture. Push to `cloud` when asked.
