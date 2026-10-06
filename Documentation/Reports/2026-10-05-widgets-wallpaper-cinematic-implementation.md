# Widgets and Wallpaper — cinematic implementation

Implemented both approved designs as native SwiftUI screens and rebuilt the exact app referenced by the Dock: `build/AllSet.app`. The app is left open on Widgets. Themes and the other tabs keep their existing screens.

Approved references: `design/widgets-concepts/2026-10-05/01-widget-library.png` and `design/wallpaper-concepts/2026-10-05-v2/03-immersive-cinema.png`. Original scenery and weather asset prompts are recorded in `design/widgets-concepts/2026-10-05/asset-manifest.json`. The reference screenshots are comparison evidence; the app uses native views, controls and reconstructed background assets.

## Result

- Widgets: dark blue alpine background, combined digital/analog clock, white/violet rim and floor reflection, side weather and analog previews, sizes and six distinct materials, customization, favorites, search, Add and drag actions, and five wide recommendation cards. Smaller windows use three columns. The complete old catalog and From Themes remain accessible through See all/category controls.
- Wallpaper: full-window alpine scene, source/search controls, real selection and preview state, caption/actions, favorites, five scenic thumbnails and a fixed bottom filmstrip. Art, imports and the existing video library remain available. Browse all opens the complete existing browser.
- Cinematic desktop widgets keep their selected style and size after saving. Existing widget files tolerate absent or malformed new fields. Applying an existing theme intentionally resets cinematic styling. Native clock geometry stays proportional when stretched; timer circles and analog dials stay circular.
- Time, calendar, weather, CPU/RAM, media and focus controls use existing real services. No reference temperatures, media titles or invented system histories were hard-coded. Actual conditions and date therefore differ from the mockups.

## Twenty review and test phases

Evidence is under `build/review/widgets-wallpaper/` (local, gitignored). Failed intermediate checks were corrected and rerun; they are retained in the logs.

| Phase | Depth and evidence |
|---|---|
| 01 | Captured the old native pages and measured gallery/wallpaper scroll baselines (`epoch-01/`). |
| 02 | Reconstructed clean offline artwork and introduced filtered discovery/layout rules; first build and core tests (`first-build.log`, `core-studio-tests.log`, asset manifest). |
| 03 | Compared first native composition with references; found scaled clock text and square lower previews (`epoch-03/`). |
| 04 | Rendered clock and recommendation faces directly at their display sizes; checked typography and five native faces (`epoch-04/`, build/render logs). |
| 05 | Checked scenic crop, luminous rim, stage alignment and reflection against the reference (`epoch-05/`). |
| 06 | Built refinements to native preview/style state (`epoch-06-build.log`); materials and sizing also exercised in final live checks. |
| 07 | Built browser/action integration (`epoch-07-build.log`); full browser and customization subsequently checked live. |
| 08 | Rendered 15 page/size combinations across 900×600, 1280×800 and 1586×992 (`epoch-08-responsive/`). Found the narrow five-card layout needed fewer columns. |
| 09 | Full core tests and optimized gallery/wallpaper probes (`epoch-09-*`). |
| 10 | First signed Dock build and native screen review (`epoch-10/`). Found the focus card background did not fill its width. |
| 11 | Real Dock controls, including physical keyboard search input. Direct AX value setting had failed to update the SwiftUI binding; scoped real typing passed (`epoch-11-live-controls-physical.log`). |
| 12 | Corrected full-width focus rendering and checked clock timing/host sizing; full tests, release, renders and gallery probe (`epoch-12-*`). |
| 13 | Add/save/remove and favorite restoration checks; old-theme compatibility; verified original widget data remained unchanged (`epoch-13-state-persistence-final.log`, compatibility tests). |
| 14 | Responsive stage/shelf checks and three-column narrow layout (`epoch-14-*`). |
| 15 | Explicit native desktop frame and proportional stretch corrections (`epoch-15-desktop-frame-*`); final added-clock window captured and inspected. |
| 16 | Matched wider weather/music cards and narrower middle cards. The expanded test expression hit a compiler type-check limit (`epoch-16-reference-shelf-tests.log`). |
| 17 | Split the geometry assertion into typed intermediate values; all 330 tests passed (`epoch-17-final-tests-corrected.log`). |
| 18 | Rechecked persisted favorites, rendering/data lifecycle and compatibility after refinements (`epoch-18-*`). |
| 19 | Final material, analog, timing and layout build; 330 tests in 86 suites passed, release and optimized DEBUG builds completed without warnings (`epoch-19-*`). |
| 20 | Final real Dock controls, persistence, actual desktop clock, five close/reopen cycles, two-size native renders, layout comparison, scroll probe and signing/binary identity checks (`final-*`). |

## Final evidence

- **330 tests / 86 suites pass.** Eighteen added tests cover filtering/search, reference geometry, responsive fit, wrapping, legacy/malformed options, saved styles/XL size, theme compatibility, favorite filename/Unicode handling, asset decode/budget and dark-blue background luminance.
- **92 live control assertions pass:** navigation, carousel, S/M/L/XL, all six clock materials, filters, matching/empty/cleared search, Customize, scene selection, Preview/Pause, source tabs, full browser and native window resizing. Twenty-one additional persistence/action assertions pass: favorite save/restore, Add exactly one cinematic clock, retained medium size, remove only that clock and canonical original widget data preserved.
- **Five native close/reopen cycles pass** in the same process. Physical footprint was 248 MB before and 245 MB after. Peak was 706 MB during the earlier broad image/control exercise; this is whole-app memory, not isolated page memory.
- Final optimized gallery scroll: first/warm CPU **24.9% / 26.0%**, p95 **17.8 / 17.7 ms**, worst **21.1 / 22.7 ms**, **zero gaps over 33 ms**, 129 pt scroll range. Old default gallery: 89.1% / 80.3%, p95 33.8 / 29.7 ms, 18 / 9 gaps over 33 ms. Content differs (full catalog versus spotlight/recommendations), so these are default-page observations, not a same-workload speedup claim.
- The earlier wallpaper vertical probe had zero scroll range and about 1.5% CPU; it measures the anchored page at rest, not horizontal-filmstrip throughput. Selection/filmstrip actions passed the live checks. GPU/WindowServer cost was not independently isolated.
- Native `codesign --verify --deep --strict` passes, including the media helper. Release and packaged app have identical Mach-O UUID and **all 36 compiled section hashes match**. Whole-file hashes differ because packaging replaces the signature. Dock points to this exact bundle.
- `leaks` reported 19.4 KB in three AppIntents `LNDaemonApplicationInterface` XPC root cycles. Its inspection was restricted on the signed process. No leak-free claim is made; the repeated-window memory check shows no growth over these five cycles.

## Reference accuracy

Manual screenshot landmark bounds, corroborated by AX positions, give **95.1/100 Widgets** and **94.5/100 Wallpaper** under this explicit layout-only metric: `max(0, 100 × (1 − mean absolute x/y/width/height error ÷ 32 pt))`. Mean error is 1.57 pt across 11 Widgets landmarks and 1.75 pt across nine Wallpaper landmarks at 1586×992. Reference readings are approximate; this score does not measure pixel similarity or certify a perfect visual match.

The mountain composition, dark-blue atmosphere, luminous clock edge, stage proportions and filmstrip were visually reviewed. Remaining differences include reconstructed artwork, native font metrics, live data, a sharper/brighter clock photo and weather illustration. Wallpaper uses **Scenic Wallpaper** for bundled moving photos and **All Displays** to reflect the existing apply behavior, rather than falsely labeling these assets as aerial footage or implying a new per-display backend.

Final artifacts:

- `build/review/widgets-wallpaper/widgets-reference-vs-native.png`
- `build/review/widgets-wallpaper/wallpaper-reference-vs-native.png`
- `build/review/widgets-wallpaper/final-renders/` — both pages at 900×600 and 1586×992.
- `build/review/widgets-wallpaper/final-live/` — 24 real Dock screenshots of control states.
- `build/review/widgets-wallpaper/epoch-15-desktop-clock.png` — actual added desktop clock, subsequently removed.
- `build/review/widgets-wallpaper/final-accuracy.json`, `final-landmarks.json`, `final-binary-sections.json`.

## Performance and scope

Scenery is static and cached with a 32 MB/eight-image bound. Tiles use paused previews and lazy rows; shader/video playback is not created on hover. Wallpaper motion requires Preview and obeys window occlusion and the existing performance policy. Window close clears the scenery cache. Monitor bars use actual histories; weather refresh honors its interval and policy scale. Decorative glow is static, without an always-running animation loop.

Set Wallpaper routes to the existing backend and retains Bring Widgets Back. It was **not clicked on the user's desktop**, because the existing operation clears widgets; the frontend implementation, undo route and existing full test suite were checked. Imported-video fetching, per-display apply and media permissions were not changed. No commit or push was made. The pre-change app backup is `build/backups/AllSet-before-widgets-wallpaper-2026-10-05.app`.
