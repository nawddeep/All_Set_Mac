# Restore the GitHub Wallpaper UI, retain current bars

User requested the older Wallpaper UI from `https://github.com/pratik-aep/all-set-mac-app.git`, with the current navigation/source bar retained.

Fetched `cloud/main`; source commit: `80dae18886c1917d7be4c286992c679e697ef326`. The retained local `ClassicWallpaperPage` matched GitHub's `WallpaperPages.swift` apart from its renamed view type, so the main Wallpaper route now uses that implementation rather than the cinematic replacement.

Restored the actual-desktop wallpaper hero, aerial category rails/See All grids, Art style rails and palettes, and My Videos' original library filters/sorting/Owned controls/detail sheet. Original playback, download, import and deletion services remain in use. Wallpaper uses its original window backdrop; Widgets retains the cinematic design.

The shared `CinemaNavigation` remains unchanged. `WallpaperSourceBar` reproduces the current source/search/heart bar and stays pinned above the original scroll content. Its search and saved-favorites filter feed the restored aerial/Art/video views; the duplicate library search field is suppressed when the shared search is provided. Existing library category, live/still, sort and Owned filters still combine with it.

Verification artifacts: `build/review/wallpaper-restore-2026-10-06/`. The first build caught a missing SwiftUI result-builder annotation on the extracted content; corrected before the final build. `release-final.log` shows a successful production build; `tests.log` reports **334 tests in 86 suites passing**; `signature.log` verifies the development-signed bundle. `bundle-identity.txt` records the executable UUID.

Reopened the exact `build/AllSet.app` (PID 4291) and visually verified the restored My Videos page: actual wallpaper hero, Import Videos, original All/Live/Stills and Sort controls, category/Owned filters and library tiles. The same primary/secondary/source bars remain above the scroll. The current library shows 829 live and 157 still wallpapers. Its existing status UI reports that the personal server is unreachable; remote-only playback remains dependent on that server. No commit/push, new media import, wallpaper apply or deletion was performed by the agent.

This supersedes the cinematic Wallpaper presentation described in the October 5 reports. Their Widgets changes remain.
