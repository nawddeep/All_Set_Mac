# Themes toolbar and smoothness — 2026-10-05

The user flagged the nested category/search bar as visually odd and asked for a smoother Themes page. The cinematic design remains in place.

## Changes

- Replaced the three nested outlines with one 48 pt toolbar, a quiet border, plain inactive category labels, one white selected pill and integrated search separated by a short divider.
- Narrow windows have a fading horizontal category rail and an All theme categories menu. Menu or shortcut selection also brings the chosen category into view.
- Moved the toolbar outside the vertical scroll view. The gallery uses one eager vertical stack with lazy horizontal rails; the pinned-header layout no longer updates as content scrolls. Changing category or entering/leaving search starts at the relevant results.
- Each cached theme image is independently observable. An image arriving no longer invalidates every other card. Eviction and purge still notify the affected consumers.
- The spotlight prepares only its two adjacent desktop previews, keeping that additional residency bounded and avoiding first-use preparation as each enters the center.
- Carousel keyboard focus is acquired after interaction, rather than every appearance. Clearing search can now remount the hero without stealing focus mid-typing.

## Checks

- Warnings-as-errors debug and optimized DEBUG builds pass. Final release packaging succeeds without compiler warnings.
- 312 tests in 85 suites pass.
- 30 native carousel/cache checks pass: existing input, looping, axis-locking and Reduce Motion coverage, plus unrelated-image observation isolation, purge notification and reloading after purge.
- Themes rendered at 900×600, 1120×760, 1400×900 and 1728×1080, including scrolled captures. The toolbar stays in place, narrow categories remain accessible and content clips below it.
- Installed bundle passes deep/strict code-sign verification. Its executable code section matches the release binary; the generated signature changes the whole-file hash.
- Live release checks: next/previous arrows, Football/All filters, Midnight Aurora pagination and typed search. Matching search returns one theme; unmatched search returns zero and No themes found. Clearing search restores browsing and allows uninterrupted typing. Log: `live-interactions.log`.

Logs, captures and the saved optimized baseline binary are in `build/review/themes-refinement/`.

## Performance

Interleaved optimized before/after/after/before comparison on this M4 MacBook Air, with build/render work finished. Each run contains two six-second scroll passes at 1280×800. The baseline is the previous cinematic layout copied before these changes. The visible Dock app and other system activity remained shared context.

| Layout | App CPU over four passes | p95 frame interval | Maximum interval | Hitches >33 ms |
|---|---|---|---|---|
| Previous toolbar/pinned header | 45.4–49.0% (mean 47.2%) | 20.6–25.1 ms | 27.0–28.5 ms | 0 |
| New fixed toolbar and cache | 41.1–44.0% (mean 43.1%) | 18.2–20.2 ms | 21.4–24.8 ms | 0 |

Average app CPU is about 9% lower in these runs; frame timing is more consistent. Both versions had zero >33 ms hitches. The scroll-layout change also changes the reported range (1850 vs 1980 pt). These are hidden-window harness measurements, not a hardware frame-rate guarantee.

Whole-run WindowServer CPU measured 39.2–39.6% before and 40.5–40.8% after. It includes other apps, the visible Dock app and window setup. No WindowServer improvement or GPU-utilization reduction is claimed. GPU utilization could not be isolated with the available permissions. Existing previews and atmosphere remain cached; no live blur was added to scrolling controls.

## Delivery

`scripts/build-app.sh` replaced the exact pinned app at `/Users/pratiksmac/Downloads/all set/build/AllSet.app`, identifier `com.pratik.allset`, using the existing development signing certificate. The app was relaunched on Themes. The previous cinematic app is backed up at `build/backups/AllSet-before-toolbar-refinement-2026-10-05.app`.

Running bundle and window verified through NSWorkspace (PID 75313 at verification). Actual release screenshot: `build/review/themes-refinement/dock-app-themes.png`. Installed/release executable code SHA256: `349e47046e35f5559f6c64e2102562f9c4934770d52d82e60d15ba263eecfc76`.

Source and documentation changes remain local, without a commit or push. Apply Theme/Preview on Desktop were not activated during verification, preserving the user's desktop.
