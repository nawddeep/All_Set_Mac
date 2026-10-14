# All Set — Wallpaper Library: architecture

_Living document. The moment implementation forces a deviation, this file is
updated in the same checkpoint and the deviation is logged in `report.md`.
Code and docs are never allowed to disagree._

_Last updated: 2026-10-03 (Home removed; Collections and Art pages removed; the app-wide sections are at the end of this file)._

## Stack, and why
| Piece | Choice | Why |
|---|---|---|
| App | Swift 6, SwiftUI + AppKit | Matches the rest of All Set. |
| Playback | AVFoundation via the existing `LoopingVideo` | Hardware decoding and the pausing rules already exist; adding a player would be a second engine (spec R5). |
| Import | Python 3 (`/usr/bin/python3`) + ffmpeg | Offline, one-off work. Keeping it out of the app keeps the app free of new dependencies. |
| Texture decoding | Swift (`scripts/wetex.swift`), compiled once | Needs DXT/LZ4 and ImageIO; ships as source, built on demand. |
| Scene rendering | Swift + offscreen **OpenGL** (`scripts/wescene.swift`), importer only | Runs each scene's **own shipped GLSL** (3–7 differing versions per effect across the packages). Chosen by the user over hand-porting or translating to Metal (2026-09-27). OpenGL is deprecated, but it is confined to the importer: already-rendered wallpapers are plain videos. |

**Division of labour:** everything expensive and one-off happens at import;
the app only plays a file. This is why 408 wallpapers, from two separate
source folders, cost the app nothing beyond one video.

## Where things live
```
scripts/
  wallpaper_library.py   inventory + import: scenes, web, video, live loops
  wetex.swift            Wallpaper Engine .tex decoder (built to Library/bin/)
  wescene.swift          scene renderer: the scene's own shaders → still or loop
  playcheck.swift        does AVFoundation really play this file?
Sources/AllSetCore/Wallpaper/
  WallpaperLibrary.swift LibraryVideo, WallpaperLibraryCatalog, LibrarySort
  WallpaperStore.swift   owns the catalog; resolves a wallpaper to a URL
Sources/AllSet/Wallpaper/
  WallpaperController.swift  plays it (LoopingVideo / MovingStill)
  WallpaperPages.swift       LibrarySection, LibraryTile
~/Library/Application Support/AllSet/Wallpaper/Library/   (not in the repo)
  catalog.json  originals/  live/  stills/  extracted/  transcoded/
  thumbnails/   scenes.json  bin/wetex  bin/wescene  import-report.json
```

## Data model
`LibraryVideo` — one wallpaper.
- `id`: first 16 hex of the content SHA-256. Identity survives renaming (R6).
- `kind`: `.video` (plays) or `.image` (a still that drifts). Missing ⇒ video.
- `root` + `file`: **provenance only** — where it came from. After R2 this is
  history, not a dependency.
- `playback`: the file on this Mac that actually plays. **The only path that
  matters at run time.**
- `status`: `quarantined` (default) / `published` / `unsupported`. Unknown
  values decode as `quarantined` — the safest reading (R4).

Decoding is deliberately tolerant: one unreadable entry is skipped, not fatal.

### Resolution rule (the heart of R2)
`WallpaperStore.libraryURL(id)`:
1. If `playback` exists on disk → use it. **Always wins.**
2. Otherwise, only for a video, fall back to `root + file` if reachable.
3. Otherwise nothing, and the caller shows the default wallpaper.

`canPlay` mirrors this without touching the disk, so grid cards never stat files.
After `--self-contained` every item has step 1, so step 2 is dead weight kept
only for a library imported without copying.

### Fetching from a personal server (optional, off by default)
`config.libraryServerURL` is nil unless a person sets it — with no server
configured, R2 holds exactly as verified (nothing but this Mac, ever). Set
(2026-09-29, one person's own Tailscale-only home server, no dedicated
settings UI yet), it adds one more fallback *after* step 3 above:
`WallpaperView`'s `.library(id)` case runs `.task(id: id) {
fetchLibraryVideo(id) }` alongside its existing fallback to default art, so a
wallpaper missing from this Mac (deleted, or freed with "Free Up Space…",
below) is fetched once and cached at the *same*
relative path (`live/<id>.mp4`…) it lives at locally — every other
resolution method sees it exactly like a normal local copy afterward, no
second code path to keep in sync. `WallpaperStore.checkServerReachable()`
follows `StatusService`'s cached, age-gated probe shape (`Sources/AllSetCore/
Developer/StatusService.swift`) so the Library grid's "can this play"
question never costs a network call per card. Download mechanics
(`URLSessionDownloadTask`, presence-check first, progress polled into an
`@Observable` dict) follow `AerialCatalog.download` exactly.
`WallpaperStore.fetchSession` is an **instance** property, not shared/static,
specifically so tests can stub it without any risk from parallel test runs.

Two real bugs only surfaced by testing the actual running `.app`, not `swift
test` (2026-09-29) — worth recording so the next feature that talks to a
server doesn't repeat either:
1. **`library` loads asynchronously**; `WallpaperView` can render before it
   has. The first fetch attempt then fails ("no server" — really "no catalog
   yet") and, without help, never retries: `.task(id:)` only reruns when its
   id changes, and the wallpaper's id doesn't. Fixed by adding
   `hasLoadedLibrary` and folding it into the task's id
   (`"\(id)#\(hasLoadedLibrary)"`), so the flag flipping true counts as a
   new id and forces a retry with real data.
2. **A successful fetch alone didn't make the view redraw.** It only
   touched `libraryCopies`, then `@ObservationIgnored`; `libraryURL(id)`'s
   file-exists check is a raw `FileManager` read Observation can't see
   either. Fixed by having the view read `fetchProgress(for:)` (backed by
   `fetches`, set then cleared around every attempt). Since the next
   checkpoint, `libraryCopies` is observed too — it changes only on load,
   fetch and offload, so it costs nothing while scrolling, and grid tiles
   need it to redraw when a copy is freed.
3. **App Transport Security blocks plain HTTP by default in a real app
   bundle** — `swift test`'s executable isn't subject to the same
   enforcement, so this looked fine right up until it ran as `.app`.
   `Resources/Info.plist` now carries one `NSExceptionDomains` entry, scoped
   to the server's exact address, not a blanket `NSAllowsArbitraryLoads`
   (that would weaken every other request the app makes).

### Freeing space: local copies become optional
- **Everything is fetched by relative path.** One private
  `fetch(relative:)` does the download; `fetchLibraryVideo(id)` and
  `fetchThumbnail(id)` resolve their own path and call it. In-flight work
  (`fetches`, `fetchTasks`) is keyed by that path, so a wallpaper's video
  and thumbnail never share a slot. The server mirrors the library's own
  layout, so the path needs no translation either way.
- **Thumbnails**: `LibraryTile` fetches one before loading it when it isn't
  on disk. The grid is lazy, so only tiles on screen ever ask.
- **`offloadAll(only:)`** deletes this Mac's copy of each playable file
  (`playback`, plus a live loop's `still`) only after a `HEAD` for that exact
  path answers 200 **with the same `Content-Length`**, and then the server's
  copy is downloaded and **hashes (SHA-256) the same** as the local file — a
  missing, truncated or different server copy keeps the local file. Same
  size alone isn't proof. 8 checks in flight at once.
  The catalog and `removed.json` are never touched: an offloaded wallpaper
  is simply "missing locally", the state already proven to self-heal.
  Thumbnails (~34 MB total) are deliberately kept, so browsing stays
  instant and works offline.
- **Surfaced as "Free Up Space…"** in the Library header (only when a server
  is configured): an estimate before confirming, per-file progress while
  checking, freed vs. kept afterward. The header counts "on this Mac",
  "checked on your server" (freed after that hash check, i.e. listed in
  `offloaded.json`) and "to download from your server (not checked)" (a
  server is configured and the catalog names the file, nothing more):
  `WallpaperStore.copyLocation`. A configured server isn't a backup until
  its files are checked. The drive-not-connected banner no longer blames a
  source drive for wallpapers the server can supply.
- **Downloads are shared, retried and cancellable** (audit, 2026-09-29): one
  `Task` per relative path, joined by every caller; the last caller to give
  up cancels the URLSession task. `WallpaperView` uses
  `fetchLibraryVideoRetrying` (backoff 2→60 s), so a server that's down or
  Tailscale connecting late at login no longer strands the wallpaper on
  default art. A response shorter than its Content-Length is rejected.
  Views read `fetching` (start/end only), never `fetches` (per-tick
  progress, Observation-ignored). A landed download bumps
  `fetchGeneration`, which re-makes the system-wallpaper still.
- **`offloaded.json`** lists every path freed on purpose; the importer
  treats those as present, so a re-import never re-renders, re-copies or
  drops `playback` for them. The active wallpaper is never freed.
- **Hover still doesn't fetch, by design, not a gap**: it shows "tap to
  preview" instead of nothing when the file isn't local. A hover firing on
  every scroll-by would download too readily; a tap is deliberate. Tapping
  opens `LibraryDetailSheet`, which does fetch.
- **Two deletes, offered the same way everywhere** (`LibraryTile.DeleteActions`;
  a filter never changes what Delete means): **Remove Download** frees this
  Mac's copy through `offloadAll(only:)`, so only after the server's copy
  is checked; **Delete Everywhere** runs `AdminGate.authorize` (Touch ID,
  falling back to the Mac password), then `WallpaperStore.deleteEverywhere`.
  That records the delete in `pendingDeletes` (written and read back
  first), asks the delete service to remove the server's files and the
  Postgres row, and only once the server confirms removes this Mac's copy
  (`deleteLibraryVideo`). The outcome is one of `.success`,
  `.notDeleted(reason)` (the server didn't confirm: nothing was deleted
  here, and asking again retries) or `.deletedOnServer(reason)` (gone
  there, but this Mac's copy or its record couldn't be fully removed:
  deleting again finishes it).
- **`scripts/cloud/delete_service.py`**: the one destructive server
  endpoint, deliberately behind more than the fetch path is. Bound to
  `127.0.0.1` on the server, not the Tailscale interface like Caddy —
  reached only through the SSH tunnel (`tunnel.sh` forwards this port
  too). Bearer-token auth on top of that (token in
  `~/.allset_delete_token` server-side, this Mac's Keychain client-side via
  `DeleteAPIKeychain`), and it only ever deletes a path that resolves
  strictly inside `~/AllSetStorage/wallpapers/`. Not a launchd service yet
  — started by hand, same as the tunnel.

## How a scene becomes a wallpaper
```
scene.pkg ─▶ an MP4 inside?  ─yes─▶ extract (a real video)
          ─▶ a GIF scene?    ─yes─▶ frames → loop
          ─▶ otherwise:
   SceneNormaliser  raw scene.json → normalised scene (data only)
     layers with their transform chain (origin, scale, rotation, parents),
     alignment, alpha / colour / brightness (as keyframe tracks),
     effects as passes of the package's own shaders: uniforms with the
     scene's values (defaults from the shader's own annotations), combos,
     textures (masks, flow maps, noise), render targets and bindings
   plan_loop        loop length 10–30 s that the scene's cycles fit; each
                    timed part's speed nudged ≤4% to land on whole cycles;
                    recording starts 60 s in (after one-shot intros)
   wescene          offscreen GL: per layer, effect passes in order; then
                    composite with the full hierarchy → still (3840) and,
                    if anything is timed, a loop (2560, HEVC, 30 fps)
   frame_movement   most-changed 1/144th of the frame ≥ 2.0/255?
                    yes → live/<id>.mp4   no → stills/<id>.jpg
```
- **Nothing is invented.** Values come from the scene; defaults from the
  shader the package ships. Mouse parallax and engine camera shake have no
  input here and are not simulated (user decision, 2026-09-27).
- **Seamless loops:** periodic parts are fitted to the loop; anything that
  can't be fitted is joined by a 1 s crossfade of the loop's tail into its
  head. Measured on a real loop: the seam step equals a normal frame step.
- **Unshipped engine pieces** are supplied once, in the renderer's prelude:
  the engine macros (`texSample2D`, `frac`, `mul`…), blur taps, HSV helpers,
  the perspective homography, `inverse`, HLSL type names and a few
  looser-typed overloads, the named blend modes, and two engine textures
  (`util/noise`, `util/clouds_256`, generated as tiling noise).
- **Particles** (60% of scenes use them: rain, snow, embers, dust, fog) are
  simulated from the scene's own emitters, initializers, operators and
  renderers (sprites, trails stretched along velocity). Each particle is a
  closed-form function of its age and a seed, and spawn times repeat every
  loop, so the particle field loops exactly with no crossfade. Settings are
  compiled to numbers once; only particles within one lifetime of "now" are
  evaluated, so cost follows the number alive.
- **Refracting particles** (`REFRACT`, e.g. raindrops) bend the picture
  behind them through their normal map instead of drawing their placeholder.
- **Engine particle sprites** (`particle/halo`, `particle/drop`, fog, beams…)
  ship with the engine, not the scene, and are its art: stand-ins of the same
  kind are generated by name family; unknown families are reported.
- **Single-channel (R8) textures** drawn as pictures are white with the
  channel as alpha, as in the engine; masks still read the raw value.
- **Keyframes are offsets** on the property's base value (a scale track named
  "1.02 to 1.15" runs 0 → 0.13 on a base of 1.02); alpha is clamped to 0–1.
- **Pass geometry follows each shader:** passes that apply
  `g_ModelViewProjectionMatrix` get the quad in pixel units; passes that write
  `a_Position` straight to the screen get it in screen space.
- **Debugging:** `WESCENE_DUMP_LAYER=<name>` writes each effect pass of that
  layer to `/tmp/wescene-dump`.
- **What isn't carried** is reported per scene (`sceneNotes` in the catalog,
  and `inspect-scene`): particles, text, sound, 3D models, SceneScript code,
  audio input (silent state), and effects whose GLSL relies on HLSL-only
  typing.

## Duplicates
`removed.json` in the library lists wallpapers taken out by a person, each
with the one kept instead and why. Every import skips them, so they never
come back. Candidates come from Apple Vision feature prints (content, largely
colour-blind), confirmed by a structural check (contrast-equalised greyscale
correlation) so mostly-dark pictures don't match each other; the final call
is made by looking. Applied with `wallpaper_library.py remove-duplicates`.

## Design decisions, and what was rejected
| Decision | Rejected alternative | Why |
|---|---|---|
| Fetch-and-cache only this checkpoint; no "delete local copy to free space" action yet | Build both together | Deleting locally is only safe once fetching back is proven; building it before that proof would let disk-freeing ship ahead of its own safety net. |
| `fetchSession` as an instance property | A shared `static` session (like the rest of this file's `static let` conveniences) | A test stubbing a shared static risks a concurrently-running sibling test's session changing underneath it; per-instance costs nothing since one `WallpaperStore` already exists per test and per running app. |
| Bake motion to a video at import | Animate layers live with Core Animation | 22 layers × 4K RGBA ≈ 730 MB of memory and per-frame GPU compositing; hardware HEVC decode is cheaper and needs no new app code. |
| Run the scene's own shaders | Whole-layer sine slides (the previous version); hand-port one version per effect to Metal; translate with glslang + SPIRV-Cross | Slides invented motion and ignored masks. A hand-port renders every other shader version wrong. Translation adds two dependencies. Running the shipped GLSL is faithful to every version. |
| Keep a still unless motion is measured, locally | Whole-frame average (the previous gate) | Faithful motion is often local (rain on a puddle, a swinging lamp); a whole-frame average called those still. Noise floor of a static picture: 0.33; threshold 1.0. |
| Blend modes ≥ 30 and object colour tint = multiply | Treat unknown modes as "replace" | The engine's enum isn't shipped. The tint effect's own default is 30 and the previews show it tinting; object mode 8 read as Color Dodge turned a BMW cyan against its preview. |
| Particles simulated per particle from age + seed | Step-by-step simulation with state | Stateless evaluation makes loops exact and any frame directly computable; a stateful sim can't loop without a visible reset. |
| Keep a loop only above 2.0/255 local motion | 1.0 (previous) | Loops that barely move looked like a soft still; the sharper still is the better wallpaper. |
| `copybackground` doesn't replace a layer's picture | Treating it as "show what's behind" | 377 ordinary layers carry it; only a render-target texture means "what's behind". |
| Copy originals byte-for-byte | Transcode them to save space | Copying is lossless and cannot change playback; these already decode in hardware. |
| Skip broken scenes by Workshop id, with reasons | Guess from a preview-image hash | Previews are square crops, zoomed, or start on a black frame; a hash cannot tell. Judged by eye instead. |
| Identity from content hash | Path or Workshop id | Files get renamed and moved; content does not. |
| Cross-root dedup by id, not just by root | Filter `kept` by root only | A second source folder can share content with the first (12 items did); filtering by root alone left both copies in `catalog.json` with the same id — a duplicate `Identifiable` for SwiftUI's `ForEach`. Fixed in the merge step itself, not worked around per-root. |

## Open assumptions to confirm
1. **~10 GB in Application Support is acceptable.** It is the price of R2.
2. **2560 px loops, 10–30 s** (chosen per scene so its cycles fit) are the right quality/size point.
3. **Motion threshold 1.0/255 on the most-changed region** is the right line between loop and still.
4. Whether `perf-audit` should be merged to `main` and pushed.


## Main window and desktop widgets (2026-10-03)
- **Page changes**: `MainView` swaps pages at once (`.id(ui.page)`, no transition); `PageVeil` (Design/WindowBackdrop.swift) fades a canvas-colored layer out with Core Animation. Never cross-fade two pages in SwiftUI.
- **Lists**: `LazyVGrid`/`LazyHStack` build children to measure them. The Gallery is one `LazyVStack` of rows with exact heights (`GalleryPage.Row`, `CardGridMetrics`); `PageScaffold` is lazy, `BleedScrollPage` eager.
- **Widget grid** (`AllSetCore/Widgets/WidgetGrid.swift`): pitch 92 pt (a quarter small cell). `spread` fills a screen after a theme; `WidgetLayout.refit` carries a layout to a new resolution.
- **Per display**: `AppSettings.screenFits[displayName]` holds each display's widget scale and the frame size it was laid out for; `AppServices.widgetScale(on:)`, `refitWidgetsToScreens()` (run from `DesktopWidgetController.tidyIfShapeChanged`).
- **Themes**: `AppSettings.activeThemeSet` (set by `adopt`, cleared by `resetWidgetLook`, part of `DesktopSnapshot`); `AppServices.turnOffTheme()`. The 2026-10-05 cinematic page uses a fixed toolbar outside its scroll view, an eager content stack and lazy horizontal rails. Its center uses a cached desktop preview; neighbours use cached portrait card art. Apply/Preview/Favorite stay below the carousel. Original offline artwork uses `ImageSource.bundled`, packaged by `build-app.sh`. Shared preview requests are reference counted until view task cancellation. Each cached image has its own observable entry, avoiding gallery-wide redraws on individual image arrivals; the hero prewarms only its two adjacent desktops.
- **Stats**: `DiskReader` and `ProcessEnergyReader` ignore gaps over 8 s (nothing was watching); `SystemMonitor.setViewer` takes a second sample 1 s after a viewer appears.

## ⌘K and toasts (2026-10-03)
- **⌘K** (`Design/SearchOverlay.swift`, `UIState.isSearching`): a glass field over the window that searches themes, widgets, library wallpapers, aerials, art, collections and pages, with ↑/↓ and Return; Esc closes. Recent searches live in `SearchRecents` (core, tested).
- **Toasts** (`Toast`/`ToastView`, `UIState.toast`): a floating glass capsule that clears itself after 2.5 s. Used by wallpaper changes, aerial download failures and theme operations.
- The Desktop section opens on Themes (the Home page was removed, 2026-10-03).

## Wrap-up (2026-10-03)
- `Deferred` (Design/DesignComponents.swift) builds below-the-fold content a frame after a page appears, under `PageVeil`. Used on Themes (shelves), Home (Favorites and Popular Widgets rails) and the Wallpaper page (aerial rails after the first). `BleedScrollPage` stays eager: a lazy one tripled Themes' scroll CPU.
- `FileThumbnail` (Components/Components.swift): a local picture file shown small, via `ImageLibrary.thumbnail(at:maxPixels:)`. Use it, not `AsyncImage`, for local files.
- `AerialCatalog.preview(for:)` decodes off main with `ImageLibrary.displayReady` and caches 60 previews (`trimPreviews` on memory pressure).
- `AppIconCache` caches bundle-id lookups and display names.
