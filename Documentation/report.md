# All Set — Wallpaper Library: report

Read only the CURRENT STATE block at the start of a session. HISTORY is a terse
log; it never needs reading in full.

---

### 2026-10-06 — video-only Wallpaper and widget motion
Wallpaper opens directly to the existing video library; all source tabs and the entire bar are removed. Aerial catalog/service/cache and unused cinematic source implementation are retired; shared generative art remains for Themes/widgets. Widget spotlight lighting now follows each footprint, and size/style controls use sliding selections in both the main page and Customize. 336 tests / 85 suites pass with no warnings; native library search/scroll and main size/style controls verified. Twelve final spotlight renders checked at two sizes. Warm scrolling has zero >33 ms gaps; first-load work and non-isolated GPU/WindowServer measurements are recorded honestly. Exact Dock app rebuilt and relaunched. See `Reports/2026-10-06-video-library-and-widget-motion.md`.

_(latest local checkpoint: 2026-10-05, five quick Themes review passes; full log in Reports/2026-10-05-themes-five-pass-review.md)_

### 2026-10-05 — five quick Themes review passes
- Visual match is partial: lighting/reflection, dense previews, shelf spacing, caption collisions and preview completeness need polish. Four sizes × top/scrolled captures reviewed; side-by-side in `build/review/themes-five-pass/reference-vs-current.png`.
- Fresh 25 targeted tests / five suites and 30 native carousel/cache checks pass. Two scroll passes: p95 17.9–18.1 ms, zero >33 ms hitches, 48.1–48.5% app CPU. WindowServer 49.4% whole-run/system-wide; no GPU isolation or comparative improvement claim.
- Installed Dock app controls verified; live search replacement remains unresolved in automation. Bundle signature and release code match verified. No implementation edits, rebuild, commit or push in this review.
- Deeper Themes work awaits the user's call. Wallpaper deferred until Themes is accepted.

### 2026-10-05 — Wallpaper design previews
- Three fresh built-in imagegen concepts saved in `design/wallpaper-concepts/2026-10-05/`, with exact prompts. Full report: `Reports/2026-10-05-wallpaper-design-concepts.md`.
- Awaiting user selection. App source and Dock build unchanged.

### 2026-10-05 — toolbar refinement (local, not committed or pushed)
- Single compact filter/search surface; narrow category menu; fixed toolbar replaces pinned-header layout.
- Per-image cache observation, two adjacent desktop previews prepared ahead, search focus preserved when the hero returns.
- 312 tests / 85 suites and 30 native carousel/cache checks pass. Four window sizes verified; exact signed Dock app replaced and relaunched on Themes.
- Interleaved comparison: mean app CPU 47.2% → 43.1% (~9% lower); p95 20.6–25.1 → 18.2–20.2 ms; zero >33 ms hitches. System-wide WindowServer sample slightly higher, no GPU/WindowServer improvement claim.
- Previous cinematic app backed up. Full logs/captures in `build/review/themes-refinement/`.


### 2026-10-05 — cinematic Themes design (local, not committed or pushed)
- Approved mockup implemented: landscape desktop spotlight, portrait neighbours, pinned filters/search, centered actions, Trending cards, Moodboards and responsive shelves.
- Original offline Midnight Aurora artwork and 12-widget theme; packaged into the exact signed Dock app at `build/AllSet.app`, running on Themes.
- 312 tests in 85 suites pass; 27 native carousel checks pass; debug/release warning checks pass; four window sizes rendered. Actual Dock app screenshot saved in `build/review/selected-design/dock-app-themes.png`.
- New optimized scroll: 29–31% app CPU, p95 18.4–19.5 ms, no hitches; WindowServer whole-run sample 41.6%, includes other apps. No GPU utilization claim or comparable HEAD speedup claim.
- Previous bundle backed up. Other tabs and backend changes await the user's next request.

Previous checkpoints:

### 2026-10-05 (pushed to cloud main and perf-audit `d6c4512`, 313 tests, 0 warnings)
- Themes hero redesign through H2 (see HANDOFF "Current state (2026-10-05)" and docs/UI-Spec.md). Next: H3 card lighting, on the user's go-ahead.
- Open: atmosphere +5 points scroll CPU (42-43% vs 37-38%), flattening test not run.

### 2026-10-03 wrap-up (details in Reports/2026-10-03-wrap-up.md)

### 2026-10-03 later (pushed to cloud main and perf-audit, 293 tests, 0 warnings)
- Home, Collections and Art pages removed; Desktop opens on Themes; art stays as the Wallpaper page's Art source. The overnight redesign (`redesign/ui`) was not taken and stays local.
- Theme previews: saving one no longer deletes other builds' cached previews (debug runs were wiping the Dock app's cache, so Themes redrew everything); photos and forecasts are fetched in parallel, only drawing is serial.
- Fixed from the app's error log: duplicate ForEach ids (music widget), cancelled-screenshot file read, preview-cache misses, Core Audio listener removal on gone devices.
- `Deferred` below-the-fold building (worst switch frame Themes ~110→70 ms, Wallpaper ~90→70); aerial previews, clipboard and My Photos thumbnails decode off main, cached. See Reports/2026-10-03-wrap-up.md.
- Open: Gallery scroll hitches, ~100 ms Island/Gallery switches.

### 2026-10-03 (earlier)
- Page switches 330-990 ms -> 45-106 ms held (`PageVeil` Core Animation fade, no SwiftUI cross-fade); Gallery is flat exact-height rows; `PageScaffold` lazy.
- Grid is quarter cells; swap-on-drop; per-display widget size (`screenFits`) with refit on resolution/monitor change; themes spread to the screen's edges.
- Themes banner = active theme (`activeThemeSet`), Turn Off Theme (undoable); Liquid Glass tabs (not yet seen live); disk/energy rates fixed after idle gaps.
- Aerial Videos stays its own tab (a move into My Videos was tried and reverted).
- Not yet seen by a person: glass tabs, a second-monitor switch, swap-on-drop.

### Earlier (2026-10-02)

### Working right now (verified only)
- **Wallpaper library: unchanged** since the 2026-10-01 docs sync (sizes, detail sheet,
  Owned filter, two deletes, server fetch/offload, redesign). Not yet seen by a person:
  the Touch ID prompt, and the redesigned Library with real wallpapers.
- **Widgets** (`4dec6f5`, `5cb9353`): snap grid, drag to a free slot, gallery drag-to-desktop,
  right-click menu; "From Themes" gallery (623 widgets, 57 themes); per-widget font, letters,
  corners, renamed built-in words and a caption below. Verified in the real app (tidy, Arrange
  drag, right-click, Remove) and offscreen renders. **Not yet seen by a person:** dragging a
  gallery card onto the desktop, and dragging a widget off the desktop outside Arrange mode.
- **Lid Plane** (`0626efc`): System → Lid Plane. Renderer checks pass, page renders with the
  live hinge reading. **Not tried:** a live capture with the effect on.
- **AI Screenshot shortcut** (`bf59f1f`): Off / ⌘⇧5 / ⌃⌥⌘5; ⌘⇧5 switches macOS's own off and
  restores it on quit. Verified in the real app with injected key presses. The user's Mac is set to ⌘⇧5.
- 263 tests, 0 warnings. **Nothing from 2026-10-02 is pushed** (3 commits ahead of `cloud/main`).
- Outside the repo: Claude Code now has the ponytail plugin enabled by default and a `/extension`
  command (`~/.claude/commands/extension.md`, `~/.claude/ponytail-ctl.js`); needs a new session.

### Known issues / blockers
- `delete_service.py` isn't a launchd service; ~700 older wallpapers lack the crossfade fix;
  no settings UI for the server URL; deleting the active wallpaper leaves it pointing at nothing.
- Gallery scroll has hitches (7-19 over 13,000 pt, 52-58% CPU), predating this work.

### Next step
The user's 7-step list: **4** analyse this Mac (hardware, sensors, permissions) and adapt;
**5** measure and fix choppiness everywhere (gallery scroll first); **6** window UI toward the
"Wallspace" reference; **7** Island Notes tab with alarms, stopwatch and daily routine reminders.

---

## DRIFT AUDIT — 2026-09-27
Code checked against `architecture.md`, section by section.
- Library folders, catalog and resolution rule: **match.**
- `originals/` reuse and orphan cleanup: **match.**
- **One mismatch:** `HANDOFF.md` still said videos play from the drive.
  Chose to **fix the doc to match the code**, since the code is verified.
Result: no code changes needed; docs now agree with reality.

## HISTORY
- Wallpaper library: importer, catalog, playback — 48 videos imported — `5b54296`
- Wallpaper library: gallery, scale probe, no-regression checks — `7608ad4`
- Handoff and session report for the import — `1e633b1`
- Scenes and web wallpapers imported (181 total, 75 live/106 stills) — `5704a87`
- Scene stills rendered as moving loops (138 live/43 stills) — `f4c2072`
- Self-contained library; survives the source folder being deleted — `30e2479`
- Phase-1 dataset (239 items) merged; cross-root dedup fixed; 408 total, self-containment reverified with both source folders absent — 29f75a4
- Scene renderer diagnosis: pipeline invents motion and drops masks, keyframes, sprites, tints; options A/B/C awaiting decision — see scene-renderer-diagnosis.md — diagnosis only, no code change
- Scenes rendered with their own shipped shaders (wescene.swift); 409 total (318 live/91 stills); dataset folder deleted after verified self-containment — pending commit
- Third dataset (all_set_mac, 516 new items) merged; 776 total (597 live/179 stills); 23 items auto-upgraded to the shader renderer; drive unmounted+remounted to prove independence — pending commit
- Particles, refraction, keyframe offsets, multi-pass geometry fixed; 24 duplicates removed; 753 total (608 live/145 stills) — pending commit
- Core bug found and fixed: loop crossfade blended the head toward a
  mismatched future frame instead of easing the tail into the true head,
  causing a white/colour flash at the start of every replay on scenes whose
  content doesn't fit the loop exactly. Confirmed on 49/321 scene loops by
  direct measurement. Fix compiled; re-render needs the drive (unmounted at
  time of fix) reconnected — not yet re-verified against real output.
- Added a manual delete button (top-right, on hover, with a confirm step) to
  each Library tile: permanently deletes this Mac's own copies, records the
  id in removed.json so re-imports never bring it back, and edits catalog.json
  as raw JSON (not through the app's narrower model) so other wallpapers'
  importer-only fields (sha256, sceneNotes...) survive untouched. New test
  proves both the permanence and the no-data-loss property. 207 tests pass,
  0 warnings, app rebuilt.
- Fourth source folder merged (all_set_mac, new drive "Nithin J", 465 new
  wallpapers); 1178 total (1008 live/170 stills); delete-button removal
  verified against real duplicate content; crossfade fix confirmed applying
  to new renders, pre-existing library still needs it — pending commit
- R1 gap fixed: a workshop item with no video and no scene package (pure
  interactive HTML/JS wallpapers) vanished with no reason logged anywhere.
  Found by checking "is everything from the pendrive actually there" against
  the raw folder, not assumed. Now every non-scene item either imports or
  gets a skip reason; 10 previously-silent items on the current dataset now
  correctly recorded as unsupported (interactive wallpapers, a documented
  non-goal) — pending commit
- Quality pass on the fourth dataset: R1 gap fixed (interactive/web items
  now logged, not silently dropped); is_blank() rejects scenes that render
  solid black or near-blank (3D-model dependency, usually); 11 already-blank
  items removed by hand after eye-checking the near-duplicate flags; 1164
  total (1006 live/158 stills); SCENE_RENDERER 9->10
- Personal home server stood up and fully proven: Tailscale + SSH key auth,
  Postgres metadata sync (1164 rows) via tunnel + Keychain password, Caddy
  serving 12.2GB/2611 files verified byte-identical, server sleep bug found
  and fixed. App-side fetch built: WallpaperStore.fetchLibraryVideo mirrors
  AerialCatalog's download shape, checkServerReachable mirrors StatusService,
  wired into WallpaperView's .library case and LibraryTile's messaging.
  Proven with a real delete-then-refetch (SHA-256 identical), not a mock.
  210 tests pass (3 new, stubbed URLProtocol, serialized). Delete-to-free-
  space deliberately not built yet, by agreement.
- Server-fetch feature proven in the real .app, not just swift test - found
  and fixed 3 real bugs invisible to the test suite: async library-load race
  (task never retried), a successful fetch not triggering a redraw
  (observed an ignored property), and App Transport Security silently
  blocking plain HTTP in a real bundle. Also found extracted/+transcoded/
  (70 wallpapers' real playback files, 7.9GB) were missing from the server
  backup entirely - pushed, now complete. Deleted the live desktop
  wallpaper's actual file and watched the running app recover it in ~12s,
  byte-identical. 211 tests pass, 0 warnings.
- Local copies made optional: thumbnails fetchable, offloadAll frees a
  playable file only after the server confirms an identical copy (HEAD +
  Content-Length), "Free Up Space…" in the Library. Real test: 4 files /
  119 MB freed from 3 real wallpapers, one fetched back by the running app
  in ~4s byte-identical. Full-library run left for the user. 216 tests.
- Full-library "Free Up Space" run for real, by explicit go-ahead: freed
  1509 files / 18.7 GiB, verified independently (disk free space, folder
  sizes, catalog/removed.json byte-identical, one freed wallpaper fetched
  back live in ~4s). Found a new real gap in the process: 294 wallpapers
  whose playback file lives under originals/ (never backed up) - the
  safety check correctly kept them rather than deleting unconfirmed
  copies. ~52GB there still has no off-Mac backup. 216 tests, no code
  changes this checkpoint (docs + the real run only).
- Audit findings fixed: retrying/shared/cancellable fetch, importer honours
  offloaded.json, active wallpaper never freed, system still refreshed after a
  late fetch, file work off the main thread. Proven in the real app with the
  server stopped at launch. 224 tests.
- originals/ pushed (280 files, 52.5 GB, verified by name+size) and freed:
  AllSet folder 797 MB, free disk 50 -> 98 GiB; one fetched back live.
- Per-wallpaper download progress bar (Library grid tiles + the desktop
  wallpaper itself): real % while a fetch is under way, replacing a bare
  spinner/nothing. Root cause of the user's "fetch not applying" report:
  clicking several tiles quickly cancels each fetch for the previous one
  (by design - correct), with zero feedback to show it was working at all.
  New WallpaperStore.fetchProgress(for:) is a plain, non-observed read;
  each view polls it on its own 150ms timer only while isFetching(id) is
  true, so redraws stay local to the one downloading tile. Verified against
  the real server: a 68 MB wallpaper landed byte-exact after hitting (and
  correctly recovering from) the async-load race on its first attempt.
  225 tests pass, 0 warnings.
- Library UI: file sizes shown, hover-preview root cause fixed (never
  fetched; now hints "tap to preview"), new bottom-up LibraryDetailSheet,
  Owned filter, two deletes (offload-only vs permanent+admin-gated).
  New server-side delete_service.py (localhost-only, tunnel+token+TouchID).
  deleteEverywhere proven for real: disposable wallpaper with a real DB
  row and server file, deleted, confirmed gone from all four places
  independently. Touch ID prompt itself not self-verified (physical
  limitation). 227 tests.
- Synced local catalog.json from the server's ongoing repair (Postgres ->
  local, raw JSON merge): 358 items repointed to the repair's live/<id>.mp4
  paths, 14 left alone because they still had a local copy (would have
  orphaned it and forced a pointless re-download), 632 already matched.
  Verified for real: fetched one repointed item (557 MB) through the
  actual store - landed byte-exact. It took 8 minutes (server busy
  transcoding), which looked like a stuck retry at first; isolated the
  retry logic outside the UI and confirmed it was never broken, just slow
  - no code change needed. Repair job still running server-side (~1000/1164
  done); re-sync again once it finishes.
- Main-window redesign merged (floating navigation; Library now Desktop → Wallpaper → My Videos); Library features checked present, 239 tests, docs synced — docs only
- Backdrop with drifting blue light, full-bleed heroes (Wallpaper, Themes, Art), theme previews wait while scrolling; scroll/galleryparts probes in CI — `3dc4479`, `928c3fd`
- Widgets (not the library): snap grid, tidy on any layout change, drag to the nearest
  slot with a live preview, gallery drag-to-desktop, right-click menu. 246 tests (7 new,
  all 57 themes keep their shape on the grid). Real app: tidy and Arrange drag landed on
  the predicted slots, menu and Remove work; gallery drop and direct drag await the user.
- Widgets: From Themes in the gallery (623 widgets, 57 themes), per-widget font, letters,
  corners, renamed built-in words (listed from the live preview) and a caption below.
  249 tests. Offscreen renders checked; gallery scroll A/B against the previous commit:
  no change (its hitches predate this, kept for the smoothness step).
- Lid Plane (Jhey's lid-fold effect, GPL) integrated as System → Lid Plane: sensor, safety
  gates, Metal renderer, capture and a settings tab; ported tests + settings tests (259).
  Renderer checks pass and the page renders offscreen with the live 128° reading; live capture
  not yet tried. Also fixed repeated Keychain password prompts (token read at launch).
- AI Screenshot shortcut (Off / ⌘⇧5 / ⌃⌥⌘5): verified in the real app via injected key presses -
  ⌘⇧5 starts the capture alone (system toolbar switched off), quitting restores macOS's
  shortcut. Found that a Carbon hotkey does not stop macOS's own ⌘⇧5, so it is switched off
  and restored. 263 tests.


## 2026-10-05 — Widgets and Wallpaper cinematic implementation

Both approved designs are now native screens in the rebuilt, signed Dock app. Widgets uses the dark blue alpine stage, luminous combined clock and native recommendation cards; Wallpaper uses the full-window scenic preview and bottom filmstrip. Existing catalog/library browsers and real data/services remain available. Twenty review/test phases completed: 330 tests pass, 92 live control assertions pass, Add/save/remove preserves the original widget data, and five window close/reopen cycles pass. Final gallery scroll has zero gaps over 33 ms. Layout landmark scores are approximately 95/100; artwork and live readings are not pixel-identical to the mockups.

See [the implementation report](Reports/2026-10-05-widgets-wallpaper-cinematic-implementation.md) for changes, evidence, performance boundaries and remaining limitations. No commit or push.

## 2026-10-05 — Studio functionality and motion follow-up

Widgets now scrolls through all 91 original catalog entries and 634 themed widgets in the main page, with original customization controls and matching purpose/search filters. Wallpaper keeps the approved hero/filmstrip and scrolls into aligned, equal-size rows of every aerial, Art and video-library entry. The same two-row navigation stays across all sections; spotlight movement and tab selection animate with the existing motion policy. Preview caching and scroll-quiet thumbnail scheduling remove the earlier multi-second Wallpaper probe stalls. All 334 tests in 86 suites pass; the signed Dock bundle is rebuilt and live controls checked. Cold/warm performance boundaries and incomplete intermediate UI harness runs are recorded in [the follow-up report](Reports/2026-10-05-studio-functionality-and-motion.md). No commit or push.

## 2026-10-06 — Restore the earlier Wallpaper UI

Restored the Wallpaper page from the GitHub repository's main branch (`80dae188`), keeping the current shared navigation and pinned source/search/heart bar. Original aerial/Art rails, video library controls and detail sheet are back; shared search filters the original content. Widgets keeps its cinematic design and complete library. See [the restoration report](Reports/2026-10-06-wallpaper-ui-restoration.md). No commit or push.


## 2026-10-06 — Wallpaper overlay and atmosphere

Wallpaper now extends behind all three navigation bars, removing the separate navy header. The original library remains beneath the full-bleed hero; its background shares Themes' glow, softened wallpaper haze and vignette. A fading contrast layer keeps the controls readable over bright media and scrolling tiles. See [the overlay and atmosphere report](Reports/2026-10-06-wallpaper-overlay-and-atmosphere.md) for build, visual and performance evidence. No commit or push.


## 2026-10-06 — Unified Themes style in Widgets and Wallpaper

Removed Widgets' frosted page treatment and scenic page backdrop. Widgets and Wallpaper now share Themes' actual cached atmosphere, solid filter surface, card edges, typography and controls. Widgets defaults to Dark, with actual adjacent previews and the full catalog; Wallpaper retains its original library and floating hero. All 334 tests pass. See [the style report](Reports/2026-10-06-unified-studio-theme-style.md) for responsive renders, live verification and measured performance boundaries. No commit or push.
