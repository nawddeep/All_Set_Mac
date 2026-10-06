# Session report: 2026-09-30, wallpaper clears widgets, sidebar remove, battery

Branch `claude/festive-brown-ks0f3c`. Cloud session, no Swift toolchain: **not
built, tested or run.** On the Mac first: `swift build 2>&1 | grep -c warning:`
(expect 0), `swift test`, then the checks below.

## Asked for, and done
1. **Picking a wallpaper clears the desktop.** Every wallpaper the person picks
   (Aerials, Art, My Videos, the library, its detail sheet, the widget photo
   picker's "Wallpaper" buttons) goes through `AppServices.pickWallpaper`:
   all widgets go, the theme's look resets (`AppSettings.resetWidgetLook`:
   font, corners, size, theme ids), and a banner offers **Bring Widgets Back**
   for 12 s (restores widgets and look, keeps the new wallpaper). A theme
   bringing its own wallpaper does not clear anything. Undo state is now
   `DesktopUndo` (theme / clearedForWallpaper), shown by `DesktopUndoBanner`
   on the Themes and Live Wallpaper pages.
2. **One-click remove** in the sidebar's *On Your Desktop* list: a trash
   button after each widget's name. No confirmation; if that widget's page is
   open, the window moves to the Gallery.
3. **Photos and My Photos removed** from the sidebar and the Live Wallpaper
   tabs (and the `photos` deep link / `-openPage photos`). They stay in the
   picture picker of Photo, Polaroid and VHS widgets, so those still work.
4. **Wallpaper preview sheet:** a clear ✕ over the preview's top-right corner,
   Esc closes it, and clicking the dimmed page behind it closes it.

## Battery and smoothness (from reading the code; measure before trusting)
| Change | Why |
|---|---|
| TapTap **rests on battery** (new setting, on by default; TapTap page toggle; Low Power toggle now shown too) | Listening reads the accelerometer ~794×/s, all day. Likely the largest constant background cost. |
| Wallpaper **art at 15 fps off the charger** (was 30) | Widgets' art already did; the wallpaper used a 30 fps cap meant for video. |
| Seconds clocks **no longer roll every second** (digital) / spring every second (analog); they animate on the minute | The perf audit measured 9–12 % CPU for a visible seconds clock (F15). |
| Idle stats sampling on battery **10 s** (was 5), Low Power 20 s, critical 60 s | Idle samples only feed sparklines and the optional menu-bar CPU %. |
| Clipboard history **written on a background queue** | Every copy re-encoded up to ~20 MB of JSON on the main thread. Quit still writes synchronously, after any queued write. |
| Library still preview **decoded off the main thread at 1600 px** | Was decoding the 3840 px original on the main thread as the sheet slid in. |
| Removed unused `PerformancePolicy.videoFrameRateLimit` | Nothing reads it now. |

## Not changed, recommended
- **Wallpaper Options → Pause on battery** is off in the saved settings. A
  4K video wallpaper decoding all day is the biggest single drain the app
  can cause; turning this on saves the most. Left as the person's choice.
- The notch watches every mouse move system-wide (needed because its panel
  ignores clicks away from the island). Cheap per event; a tracking-area
  redesign would need profiling on the Mac first.

## To check on the Mac
1. Apply a theme, then pick an Aerial: widgets clear, banner shows; Bring Widgets Back restores them with the new wallpaper kept.
2. Trash icon beside a widget in the sidebar removes it at once.
3. Sidebar has no Photos / My Photos; Live Wallpaper tabs are Aerial Videos, Art, My Videos.
4. My Videos → open a library item: ✕ top-right, Esc, and clicking outside all close it.
5. Unplug: TapTap page says Resting; plug in: Listening. `-probe widgets` with a seconds clock should drop well below 9 %.
