# All Set: performance and resource audit

Working log for the audit. Phases are appended in order. Every number says how it was obtained: **[measured]** means a profiler or OS counter on this Mac; **[reasoned]** means static analysis of the code.

Inventory corrections to the brief: the code has 54 widget kinds (not 52), 49 themes (not 43) and 41 palettes (not 33). The inventory file is `CONTENT.md`.

---

## Phase 0: tooling

| Tool | Available | Used for |
|---|---|---|
| `swift build` / `swift test` | yes | builds, 193 unit tests |
| Xcode 26.3, `xcodebuild` | yes | not needed (SwiftPM project) |
| `xctrace` (Time Profiler, Allocations, Leaks, Animation Hitches, Power Profiler) | yes | CPU sampling of the running app. The "CPU Profiler" template recorded no samples on this Mac; "Time Profiler" works. |
| `leaks`, `heap`, `footprint`, `vmmap`, `sample` | yes | leak and retain-cycle check, heap census, memory footprint |
| `powermetrics` | **no** (needs sudo) | no package-power numbers; energy is inferred from CPU time |
| App's own DEBUG probes (`-probe …`) | yes | CPU per view/page, frames lost, before/after comparisons |

**Mode: runtime profiling is possible.** I can build, launch and profile the app, so measured numbers are real. Limits:
- There's no power-rail data (no sudo).
- WindowServer CPU can't be attributed per app, so it's measured by quitting and relaunching All Set (A/B).
- The user was using the Mac during the runs, which adds noise.

## Measured baseline (before any change)

The Dock app was launched at 04:37 and had been running 12 h. It had 11 desktop widgets (Neon Nights–style set), a photo wallpaper, Now Playing and clipboard monitoring, and the main window had been opened and closed during the day.

| What | Number | How |
|---|---|---|
| App CPU, 12 h average | **0.24 %** of one core (104.5 s CPU in 11 h 59 m) | [measured] `ps cputime` |
| App CPU, idle, 60 s | **0.66 %** (397 ms of samples) | [measured] xctrace Time Profiler |
| Now Playing helper (perl) | 2.2 s CPU in 12 h (~0.005 %) | [measured] `ps` |
| WindowServer, app running vs quit | 7.5 % vs 7.0 % (difference within noise); 14.2 % in the minute after relaunch | [measured] `load.sh`, A/B |
| Memory footprint, fresh launch | **106 MB** | [measured] `footprint` |
| Memory footprint after 12 h | **533 MB (peak 790 MB)**: IOSurface 184 MB, malloc 161 MB, decoded images ("CG raster data") 116 MB | [measured] `footprint`, `heap` |
| Leaks | 38 blocks, 4 KB total; one retain cycle (see F9) | [measured] `leaks` |

Where the 0.66 % idle CPU went, from 60 s of samples [measured]:
- Main thread 0.48 %. Of that, 0.30 % is layer drawing (Core Animation commit), 0.10 % SwiftUI graph updates, 0.04 % timers and 0.04 % mouse-event monitors.
- System sampler 0.08 %: disk capacity, IOKit, battery, temperatures, process list.
- Blur re-rasterized on the CPU: 0.10 % (`vSepConvolveARGB8`, from `RB::CGContext::apply_blur` in an animating SwiftUI view: the neon sign's flicker).
- Wallpaper coverage check 0.04 %; clipboard poll 0.01 %.

**Takeaway:** steady idle CPU is already low. What goes wrong over a long session is (a) **background work left running after the main window closes**, and (b) **memory kept after it's no longer needed.** F1–F3 below prove both.

---

## Phase 1: resource map

Legend for the "hidden" column (does it keep running when its UI is hidden, covered or inactive?): **stops** / **slows** / **KEEPS RUNNING**.

| # | Subsystem (file) | Trigger | Interval | Thread / QoS | I/O or network | Owner, cancellation | When hidden |
|---|---|---|---|---|---|---|---|
| 1 | Island pointer tracking (`Notch/NotchController.swift`) | Global and local `NSEvent` monitors for mouse moved, drag, down and up | every mouse event system-wide | main | none | `eventMonitors`, app lifetime | **KEEPS RUNNING** (needed to detect hover; cheap: a rect test per event, 0.04 % [measured]) |
| 2 | Island backstop timer (same file) | `Timer` | 0.15 s | main | none | `pointerTimer`, invalidated on collapse | stops (only while expanded) |
| 3 | Island shape and animations (`Notch/IslandView.swift`) | Core Animation springs on state change | per change | WindowServer | none | layer, app lifetime | stops (no loop) |
| 4 | Island warm-up (`IslandView.warmUp`) | one `Task` 2 s after launch | once | main | none | a throwaway model and view, closed after | the throwaway model is **never freed** (retain cycle, F9) |
| 5 | Island live activities (`NotchController`) | media, volume, power and knock callbacks; transient `Task`s | per event | main | none | `transientTask` / `nowPlayingHideTask`, cancelled when superseded | stops |
| 6 | Island Home tab progress (`Notch/HomeTab.swift`) | `TimelineView` | 1 s while playing, 1 h paused | main | none | SwiftUI | stops (only mounted while expanded) |
| 7 | Desktop widget windows (`Widgets/DesktopWidgetController.swift`) | one window per widget; occlusion notifications | per change | main | none | `windows`, `occlusionObservers` | stops or slows (occlusion drives `widgetIsVisible` and `widgetIsOnScreen`) |
| 8 | Animated widget layers (`Components/LiveLayers.swift`, `MysticWidgets.swift`, …) | Core Animation loops, `preferredFrameRateRange` 10–30 fps | continuous in WindowServer | WindowServer | none | `LiveLayerView.isRunning` | stops when covered, in Low Power Mode, or with Reduce Motion |
| 9 | Widget clocks and text (`TimelineView` in 25 places: clocks, calendar, dates, quotes, mystic…) | SwiftUI schedule | 1 s (clock with seconds, running focus) to 1 h; mostly `everyMinute` | main | none | SwiftUI | **NEEDS VERIFICATION**: SwiftUI doesn't know a window is occluded, so these probably keep firing under covering windows. Cost per tick is one widget redraw. |
| 10 | Neon sign flicker (`Kinds/DarkWidgets.swift`) | `.task` loop | burst every 5–13 s | main | none | SwiftUI task, keyed on visibility | stops when covered; **each burst re-blurs four text shadows (up to radius 34) on the CPU** [measured 0.10 %] |
| 11 | Generative art (`Widgets/ArtView.swift`, `ArtShader.swift`) | MTKView (GPU) or `TimelineView(.animation)` fallback | 24 fps (15 on battery) | GPU / main | none | view | stops (`isVisible` gate) |
| 12 | Widget data refresh (`Design/WidgetComponents.swift` `widgetRefresh`) | `.task` loop | wakes every ≤ 60 s; work is due per `RefreshPolicy` | main | network through services | SwiftUI task, keyed on `widgetIsOnScreen` | stops when covered |
| 13 | Weather and air quality (`AllSetCore/Weather/Weather.swift`) | called by #12 | 15–60 min max age | async | HTTPS (Open-Meteo) | merged by an `inFlight` key; disk cache | stops (no callers) |
| 14 | GitHub, status checks (`AllSetCore/Developer/*.swift`) | called by #12 | 5 min–1 h / 30 s–10 min | async | HTTPS | merged by `inFlight`; GitHub disk cache | stops |
| 15 | System monitor (`AllSetCore/System/SystemMonitor.swift`, `SystemSampler` actor) | `Task` sleep loop | fastest viewer (1–5 s); idle 3 s (5 on battery, 10 in Low Power) | sampler actor off main; publishes on main | IOKit, `proc_pidinfo`, `statfs` | `loop` task; `viewers` dictionary | slows when idle but **never stops** (3 s quick sample; detailed every 30 s). **After the main window closes, its viewer stays registered: 2 s detailed sampling forever (F1).** |
| 16 | Main window (`MainWindow.swift`) | built on first open | — | main | — | `MainWindowController.window`, `isReleasedWhenClosed = false` | **KEEPS RUNNING**: the whole page tree stays alive after close (views, observation, timers, images, layers) (F1, F2) |
| 17 | Live wallpaper (`Wallpaper/WallpaperController.swift`) | occlusion, lock, sleep, power and app-switch notifications, plus a coverage `Timer` | coverage check every 2 s | main | reads the window list | `observers`, `coverageTimer` | playback stops (covered, locked, asleep, Low Power, optionally battery). **The coverage timer runs even for a still photo with no motion (F7).** |
| 18 | Wallpaper video (`SharedVideoPlayers`) | AVPlayer, reference-counted per URL | continuous while playing | AVFoundation | disk decode | released per viewer | stops (paused when hidden) |
| 19 | Core Audio mixer (`Mixer/MixerController.swift`, `AllSetCore/Audio/*`) | Core Audio property listeners; taps only for apps not at 100 % | events | main + audio IO thread | none | `router`; tap stopped 2 s after silence | stops (taps idle when silent) |
| 20 | Volume and device HUD (`AllSetCore/Audio/VolumeMonitor.swift`) | Core Audio listeners | events | main | none | app lifetime | event-driven |
| 21 | TapTap sensor (`AllSetCore/Knock/*`) | IOHID input reports (~1 kHz) plus a 1 s watchdog `Timer`, plus global key and mouse monitors | ~1 kHz while listening | HID callback thread | none | `sensor`, `watchdog`, `monitors` | stops when disabled, asleep, display asleep, locked or in Low Power Mode |
| 22 | Clipboard monitor (`Clipboard/ClipboardMonitor.swift`) | `Timer` comparing `changeCount` | 0.5 s (1 s on battery) | main | image save and OCR off main | `timer`, app lifetime | **KEEPS RUNNING** by design: macOS has no public clipboard-change event. Cost 0.01 % [measured]. |
| 23 | Clipboard OCR (`ClipboardMonitor`, Vision) | on demand per image | — | detached utility task | disk | — | on demand |
| 24 | Now Playing helper (`Sources/MediaHelper/MediaHelper.m`, a perl process) | MediaRemote notifications + a 10 s safety timer | 10 s | helper process, main queue | XPC to mediaremoted | `MediaController` restarts it on exit | **KEEPS RUNNING** (2.2 s CPU in 12 h [measured]; negligible) |
| 25 | Calendar (`AllSetCore/Calendar/CalendarService.swift`) | `EKEventStoreChanged` + a 300 s loop | 5 min | main | EventKit | `refreshLoop`, app lifetime | **KEEPS RUNNING** without any calendar viewer (cheap) |
| 26 | Window snapping (`Workspace/WindowManager.swift`) | global mouse down, drag and up monitor; Carbon hotkeys | per event | main | Accessibility calls on snap | app lifetime | event-driven |
| 27 | Workspace restore (`Workspace/WorkspaceController.swift`) | polls for new windows | 250 ms, at most 32 times | main | Accessibility | per restore | only during a restore |
| 28 | Photo and wallpaper search (`AllSetCore/Aesthetics/PhotoSearch.swift`) | typing, debounced 400 ms; paced per site | on demand | main + URLSession | HTTPS; disk cache | `task` cancelled when superseded | on demand. The in-memory page cache has no limit (small). |
| 29 | Image library cache (`AllSetCore/Aesthetics/ImageLibrary.swift`) | on demand | — | decode off main | disk, HTTPS | `memoryCache` (≤ 40 images), `smallCache` (≤ 80) | **count-bounded, not byte-bounded**: 40 × a decoded 3200 px image ≈ 1 GB worst case; clears everything at once when full (F4) |
| 30 | Artwork cache (`Components/LiveLayers.swift` `ArtworkCache`) | on demand | — | render main, glow blur off main | none | LRU, 60 entries | count-bounded only (F4) |
| 31 | Theme previews (`Studio/ThemePreviews.swift`) | on demand per visible card | — | serial render queue | disk cache | `images` dictionary, **never evicted** | 1136×768 px ≈ 3.5 MB decoded each, up to ~170 MB for all 49 [reasoned from the size]; kept after the window closes (F2) |
| 32 | AI screenshot editor (`Screenshot/ScreenshotStudio.swift`) | on demand | — | main + network | HTTPS (Anthropic, OpenAI) | `states`, one full image per edit, **no limit** | per session (F6) |
| 33 | Aerial download progress (`AllSetCore/Wallpaper/AerialCatalog.swift`) | `Task` loop | 250 ms | main | download | ends with the download | only while downloading |
| 34 | Energy policy (`AppServices.swift` `EnergyMode`) | power-state, accessibility and power-source notifications | events | main | none | app lifetime | read by the wallpaper, widgets, clipboard and monitor pace. **Thermal state is ignored; network refresh and the island don't use it (F5).** |
| 35 | Memory pressure | — | — | — | — | — | **nothing responds to memory pressure (F4)** |

---

## Phase 2: findings, ranked by evidence

### CRITICAL

**F1. Closing the main window leaves its work running until you quit.** [measured]
- **Evidence:**
  - `MainWindowController` keeps the window with `isReleasedWhenClosed = false`, so the SwiftUI tree survives a close.
  - SwiftUI does not send `onDisappear` when a window is ordered out.
  - The Dynamic Island page (the default page) registers `monitor.setViewer("window", visible: true, interval: 2)` in `onAppear`. The System Monitor page does the same.
- **Probe `-probe windowclose`:** viewers are `["window": 2.0]` while the window is open, and **still `["window": 2.0]` after it's closed.**
- **App CPU:** **0.09 %** in the 30 s before the window was ever opened, **0.89 %** in the 30 s after opening and closing it once. That's a 10× increase, for the rest of the session.
- **Criteria met:** runs continuously with no visibility gate; the resource has no cancellation path.

**F2. Memory built up by the main window is never given back.** [measured + reasoned]
- **Evidence:** the footprint is 106 MB at launch and 533 MB (peak 790 MB) after 12 h. Leaks account for 4 KB, so this is retained memory, not leaked memory.
- **The retained window keeps:**
  - its page's layers (IOSurface, 184 MB total);
  - theme previews at about 3.5 MB each in an `images` dictionary that's never evicted (#31);
  - photo thumbnails and search results.
- **Criteria met:** unbounded cache; no owner releases it.

### HIGH

**F3. The system monitor never stops sampling, even with no viewer at all.** [measured + reasoned]
- **Evidence:** the idle loop takes a quick sample every 3 s and a detailed one every 30 s, for as long as the app runs.
- **Why it exists:** only to keep the sparkline history warm and the optional menu-bar CPU readout. With no viewer and the readout off, nobody sees the result.
- **Cost:** measured idle cost of the sampler is about 0.08 %. Each sample also republishes `snapshot`, which invalidates observers.
- Not CRITICAL, because the interval is 3 s and not below 250 ms.

**F4. Image caches are bounded by count, not bytes, and nothing reacts to memory pressure.** [reasoned + measured context]
- **Evidence:**
  - `ImageLibrary.memoryCache` holds 40 full-size images (decoded up to 3200 px, about 25 MB each) and `smallCache` holds 80.
  - Both call `removeAll()` when full, which re-decodes everything visible at once.
  - `ArtworkCache` holds 60 entries.
  - No `DispatchSource.makeMemoryPressureSource` anywhere.
- **Measured context:** "CG raster data" (decoded images) was 116 MB after 12 h.

**F5. There's no single performance policy, and thermal state is ignored.** [reasoned]
- **Evidence:** `EnergyMode` covers Low Power, Reduce Motion and battery, but:
  - `ProcessInfo.thermalState` is only displayed, never acted on;
  - widget network refresh (`RefreshPolicy`) doesn't slow in Low Power Mode or when the Mac is hot;
  - frame-rate caps are constants scattered across the layer classes (10–30 fps).
- **Consequence:** a hot fanless Air keeps the same animation and refresh load.

### MEDIUM

**F6. The screenshot editor's undo history has no limit.**
- **Evidence:** `ScreenshotStudio.states` appends a full-resolution image per edit, with no cap, for the life of the editing session.

**F7. The wallpaper coverage timer runs when nothing can move.**
- **Evidence:** `scheduleCoverageCheck(active: allowed && config.pauseWhenCovered)` ignores whether the source animates at all. A still photo (motion `.still`) gets a window-list query every 2 s [measured 0.04 %].

**F8. The neon sign flicker re-blurs four shadows on the CPU every burst.**
- **Evidence:** the profile shows `RB::CGContext::apply_blur` → `vSepConvolveARGB8` from an interpolating display list, 58 ms per minute [measured]. The code comment claims it "costs nothing". That claim is wrong, though the cost is small (0.1 %).

### LOW

**F9. The island warm-up leaves one retain cycle.**
- **Evidence:** `leaks` shows `ROOT CYCLE: <NotchViewModel>` via its observation registrar.
- **Cause:** `IslandView.watch` captures the model strongly inside a closure stored in the model's own registrar. It's 2 KB, once, but it's a real lifecycle bug.

**F10. Calendar refreshes every 5 minutes with no viewer.** EventKit query, cheap.

**F11. The Now Playing helper keeps a 10 s safety poll.** It's a backstop for players that don't post notifications. 2.2 s CPU in 12 h [measured]. Keep.

**F12. The photo search page cache has no limit.** Small (a few KB per page), per session.

**F13. Mixer observers are never removed.** The `didBecomeActive` observer token is discarded; the object is app-lifetime, so this is harmless.

**F14. Widget `TimelineView`s may tick under covering windows** (NEEDS VERIFICATION, #9). The cost per tick is one small redraw.

### Checked and fine (no change planned)
- **Mixer taps** only exist for apps not at 100 % and stop 2 s after silence.
- **TapTap** is fully gated: enabled, awake, display awake, unlocked, not in Low Power Mode.
- **Network services** merge in-flight requests and cache by age.
- **Widget animations and art** stop when covered.
- **Wallpaper playback** is gated on many signals.
- **Sparkline histories** are bounded at 60; clipboard history at 200, and its images are deleted when trimmed.
- **Island animations** run in WindowServer; the 0.15 s timer runs only while the island is open.

---

## Phase 3: changes

Each change was built, tested (200 tests pass, 0 warnings) and measured before the next. Commits on branch `perf-audit`:
- `05899ce`: main window and memory
- `1bed2d7`: performance policy
- `0aaad06`: events, bounds, lifecycle, launch
- `3e8dd6d`: covered widget timelines

New DEBUG probes, for re-measuring:

| Probe | Checks |
|---|---|
| `-probe windowclose` | viewers, CPU and footprint around opening and closing the main window |
| `-probe covered` | a widget visible vs. covered (`ENTRY=` and `SIZE=` pick it) |
| `-probe desktopwidgets` | each widget on your desktop alone |
| `-probe neon` | the neon flicker's cost |

### Fix 1. Main window let go on close (F1, F2)
**File:** `Sources/AllSet/MainWindow.swift`

**Problem:**
- The window was kept (`isReleasedWhenClosed = false` plus a strong reference), and SwiftUI sends no `onDisappear` to a hidden window.
- The default page's `monitor.setViewer("window", interval: 2)` stayed registered after closing, so detailed sampling every 2 s ran forever.
- Everything the page had drawn stayed in memory.

**Fix:** `windowWillClose` drops the content view controller and the window. `UIState.page` remembers the page, so reopening shows the same page. Closing also calls `releaseCachedPictures(keeping: 0.25)`.

**Why it helps (measured, `-probe windowclose`):**

| | Before | After |
|---|---|---|
| Viewers after close | `["window": 2.0]` | `[:]` |
| App CPU after close | 0.89 % | 0.10 % (never opened: 0.09 %) |

Reopening registers again, correctly.

**Tradeoff:** reopening rebuilds the page (tens of ms). Transient view state such as scroll position resets. Search text on the Photos page is restored from `PhotoSearch.query`.

### Fix 2. Picture caches limited by bytes and released when not needed (F2, F4)
**Files:**
- `Sources/AllSetCore/Support/CostCache.swift` (new, 3 tests)
- `Sources/AllSetCore/Support/ImageCost.swift` (new)
- `Sources/AllSetCore/Aesthetics/ImageLibrary.swift`
- `Sources/AllSet/Studio/ThemePreviews.swift`
- `Sources/AllSet/Components/LiveLayers.swift` (`ArtworkCache`)
- `Sources/AllSet/AppServices.swift`

**Problem:**
- The caches were bounded by count only (40 photos, 80 small copies, 60 artworks) and cleared everything at once when full.
- Theme previews were never evicted, and stored at 16 bits a channel (`ImageRenderer`'s output): 7 MB each [measured: 1136×768, 9088 bytes per row].
- Nothing listened for memory pressure.

**Fix:**
- A least-recently-used cache bounded by bytes and count. Limits: photos 160 MB/40, small copies 96 MB/120, artworks 64 MB/60, previews 48 MB beyond the cards on screen (which always keep theirs), photo search 200 pages.
- Previews and artwork are stored as 8-bit screen-format pixels (`ImageLibrary.displayReady`).
- `releaseCachedPictures` runs when the main window closes (down to 25 %) and on a `DispatchSource` memory-pressure warning (50 %) or critical event (0).
- A purge cancels queued preview work and ignores results that land afterwards (generation counter).

**Why it helps (measured, `-probe windowclose`, Themes page open 12 s):**

| Footprint | Before | After |
|---|---|---|
| Opening the page | 69 → 333–351 MB | 71 → 77–79 MB |
| After closing | 327–351 MB (nothing released) | 67–70 MB (every cache empty) |

**Tradeoff:**
- Scrolling back to a preview that was evicted reloads it from disk, a few ms off the main thread.
- 8-bit previews lose 16-bit precision the screen can't show; checked visually with `-renderThemeSets`.

**Regression found and fixed while verifying:** the first version evicted previews of cards still on screen, which then showed spinners. The cache now tracks visible cards (`showing`) and never evicts theirs. Re-verified: every card loads.

### Fix 3. One `PerformancePolicy` for power and heat (F5)
**Files:**
- `Sources/AllSetCore/Support/PerformancePolicy.swift` (new, 4 tests)
- `Sources/AllSet/AppServices.swift`
- `Wallpaper/WallpaperController.swift`, `Widgets/WidgetHostView.swift`, `Clipboard/ClipboardMonitor.swift`
- `Design/WidgetComponents.swift` and five network widgets

**Problem:** `EnergyMode` knew Low Power, Reduce Motion and battery, but not `thermalState`. Limits were constants in each subsystem, and network refresh never slowed down.

**Fix:** one struct decides a tier (full / balanced / saver / minimal) from all four signals, and every consumer reads its limits from it:
- decorative motion
- art and video frame rate
- idle and minimum stats interval
- clipboard pace
- network refresh scale (`widgetRefreshScale`)

It observes `ProcessInfo.thermalStateDidChangeNotification`.

**Why it helps:** a hot fanless Mac now sheds decorative animation and background work, as Low Power Mode already did. Network widgets wait 2–4× longer in the saver tiers. [Reasoned; unit-tested tier table. Not measured under real thermal pressure, since I couldn't make the Mac hot on demand.]

**Tradeoff (behaviour change, deliberate):**
- At `serious` or `critical` thermal state, decorative motion pauses, as it already did in Low Power Mode.
- At `fair`, limits drop to the battery tier.
- Battery and Low Power behaviour is identical to before (tested).

### Fix 4. The system monitor idles on cheap readings only (F3)
**File:** `Sources/AllSetCore/System/SystemMonitor.swift`

**Problem:** with no viewer, every 10th idle tick (30 s) did the full detailed pass: every process, disk capacity, IOKit temperatures, battery registry.

**Fix:** idle ticks take quick samples only, at the policy's pace. The detailed pass runs immediately when any viewer appears (existing `setViewer` behaviour), so nothing on screen shows stale detail.

**Why it helps (measured, idle app with no windows):** 0.09–0.11 % → **0.03–0.04 %** CPU (two runs each).

**Tradeoff:** the menu-bar readout shows only CPU, which is still sampled. Temperatures and per-app energy aren't refreshed until something shows them, and nothing idle does.

### Fix 5. Calendar: events instead of a 5-minute loop (F10)
**File:** `Sources/AllSetCore/Calendar/CalendarService.swift`

**Problem:** a `Task` loop refetched every 300 s, forever.

**Fix:** refresh on:
- `EKEventStoreChanged` (as before);
- `NSCalendarDayChanged` and `NSWorkspace.didWakeNotification`;
- a single timer set for the moment the soonest event ends.

**Why it helps:** no periodic work, and ended events now leave the list on time (they could linger up to 5 min before). [Reasoned]

**Tradeoff:** none known. Relative labels ("in 10 min") are computed by the views as they draw.

### Fix 6. Covered widgets stop their timelines (F14, confirmed)
**Files:** `Sources/AllSet/Widgets/Design/WidgetComponents.swift` (`WidgetTimeline`, `PausableSchedule`), and all 24 `TimelineView`s in `Widgets/Kinds/*`.

**Problem:** SwiftUI keeps redrawing a window nobody can see. Measured with `-probe covered`: a digital clock showing seconds cost 12.6 % CPU visible and **12.7 % fully covered**.

**Fix:** widget timelines use a schedule that yields no further dates while `widgetIsOnScreen` is false (desktop windows set it from occlusion). When uncovered, it starts again from the current time.

**Why it helps (measured):**

| Clock with seconds, covered | Before | After |
|---|---|---|
| Small | 9.9 % | **0.034 %** |
| Medium | 12.7 % | **0.036 %** |

The same mechanism applies to every ticking widget: clocks, calendar, focus, daylight, mystic and others.

**Tradeoff:** none visible. A covered widget is behind a window.

### Fix 7. Screenshot editor keeps 24 versions (F6)
**File:** `Sources/AllSet/Screenshot/ScreenshotStudio.swift`

**Problem:** one full-size picture (about 60 MB for a 5K screenshot) per edit, with no limit.

**Fix:** keeps the original plus the last 24 versions; the oldest edits drop first.

**Tradeoff (behaviour change):** undo reaches 24 steps back, not unlimited. The original is always kept.

### Fix 8. Lifecycle fixes (F9, F13)
**Files:** `Sources/AllSet/Notch/IslandView.swift`, `Sources/AllSet/Mixer/MixerController.swift`

**Problem:**
- `IslandView.watch` captured its model strongly inside a closure stored in the model's own registrar, so the warm-up's throwaway island was never freed (`leaks`: ROOT CYCLE `NotchViewModel`).
- The mixer discarded an observer token.

**Fix:** capture the model weakly; keep the token and remove it in `stop()`.

**Why it helps (measured):** `leaks` on the rebuilt app after warm-up: **0 leaks, no cycles** (before: 38 leaks, 1 cycle).

### Fix 9. Wallpaper work only when it matters (F7, launch)
**File:** `Sources/AllSet/Wallpaper/WallpaperController.swift`

**Problem:**
- The 2 s coverage check ran even for a still photo, which has nothing to pause.
- Every launch re-rendered the art still, encoded a PNG and set it as the system wallpaper, even when nothing had changed.

**Fix:**
- Coverage checks run only when the source can move (art, video, drifting photo).
- The still's source and path are remembered; when every screen already shows that still, launch skips the work.

**Why it helps (measured, xctrace launch profiles, first 15 s):** `WallpaperController.writePNG` (105–113 ms) disappears. Launch CPU 1.71 s → **1.59 s** (1.96 s on the launch that wrote a fresh still).

### Fix 10. Island warm-up after the launch burst
**File:** `Sources/AllSet/Notch/NotchController.swift`

**Change:** warm-up at +6 s instead of +2 s, so its ~125 ms doesn't compete with launch.

### Not changed, with reasons
- **Clipboard polling:** there's no public macOS clipboard-change event, and one check costs 0.01 % [measured]. The pace now comes from the policy.
- **Now Playing 10 s safety poll:** it catches players that don't post notifications [measured 2.2 s CPU in 12 h].
- **Neon flicker (F8):** the flicker costs nothing measurable. `-probe neon`: 0.120 % with flicker vs 0.131 % without over 60 s, within noise. **Correction to F8:** the CPU blur in the 12-hour profile did not come from the neon flicker. The most likely source was the retained main window (F1) still animating its island preview, whose shadows blur on the CPU; that window is now released. [Reasoned; the rebuilt app's idle profile in Phase 4 checks it.]
- **Per-widget costs:** `-probe desktopwidgets` measured each of the 11 desktop widgets alone for 20 s. All were within about 0.5 % of an empty window, and a profile of the flip clock showed its own work is negligible (the rest was the probe's stats sampling).

### New finding while fixing: F15, a visible clock with seconds costs 9–12 % CPU (HIGH, not fixed)
- **Measured:** `-probe covered` showed 9.5 % (small) and 12.3 % (medium) visible, with the seconds option on.
- **Cause:**
  - `TimeLabel` animates the digits every second with `.contentTransition(.numericText())` and `Motion.standard`.
  - The medium clock's `AnalogFace` gives its hands a bouncy spring every second.
  - Each animation redraws the card's layers on the CPU for about a third of every second (profile: `CA::Transaction::commit` → CGDrawingLayer, `argb32_image_mark`, `vSepConvolve`).
- **Tried:** `.drawingGroup()` only reached 8.6 %; reverted.
- **Why not fixed:** a proper fix moves the rolling digits into Core Animation (CATextLayers with a push transition, as `TickingText` does for the stopwatch). But those layers would have to reproduce every design theme's typography (design, width, custom fonts) and ink colour. The simpler alternative, digits that change without rolling, changes how the clock looks. This needs your decision (see Phase 5).
- **Exposure:** seconds are off by default, and your desktop's flip clock doesn't show them. Covered, it now costs nothing (Fix 6).

---

## Phase 4: combined workload

### What was run
**Scenario:** your 11 desktop widgets and your wallpaper, the island held open on the System tab (live stats every second), clipboard monitoring and the mixer's Core Audio listeners. Main window skipped.

**Method:** the audit's starting code (`20b4b70`, in a separate worktree) vs. the current branch, interleaved baseline / new / baseline / new. 30 s to settle, then 60 s measured with `ps` (app and WindowServer CPU time) plus `footprint`. Script: `scratchpad/perf/combined.sh`.

| Round | Build | App CPU | WindowServer | Footprint |
|---|---|---|---|---|
| 1 | baseline | 5.48 % | 27.7 % | 75 MB |
| 1 | new | 1.88 % | 9.2 % | 74 MB |
| 2 | baseline | 2.75 % | 15.7 % | 75 MB |
| 2 | new | 2.77 % | 15.7 % | 77 MB |

**Reading, honestly:** round 2 is identical, and round 1's gap is almost certainly your activity during the run. WindowServer swung between 9 % and 28 % between rounds, which is what it does while you're working. **Under full visible load the two builds cost the same.**
- That's expected: this scenario keeps everything visible and open, the one state the fixes deliberately leave alone (no feature is degraded).
- The savings are in the hidden, closed, covered and idle states, measured individually in Phase 3.
- **No regression.** [measured]

### The real Dock app after the fixes [measured]

**Idle, 60 s, 11 visible widgets, window closed:** 0.66 % CPU, the same total as the baseline. The mix changed:
- The detailed stats pass (disk capacity, temperatures, process walk) no longer appears.
- `RB::CGContext::apply_blur` shows up in 1 sample (baseline: dozens).
- What remains is your visible widgets' own work: the terminal and system widgets redrawing with stats every 2 s, and the neon sign. It's live data you can see.

**Main window on Themes, then closed, with previews already on disk:**

| | Footprint | Peak |
|---|---|---|
| After launch | 101 MB | 278 MB |
| On Themes | 114 MB | 278 MB |
| After closing | 105 MB | 278 MB |

**When previews had to be drawn from scratch** (a first visit): 104 → 287 MB on Themes and 214 MB after closing, with a **peak of 738 MB**. The live heap after closing was 142 MB, much of it pictures the caches deliberately keep at 25 %. The rest is allocator high-water that isn't returned right away. See Remaining risks.

### Combination effects [reasoned]

**Concurrent decorative animations use mismatched frame rates.**
- Core Animation loops request 10, 12, 20, 24 or 30 fps, and art runs at 24 (15 on battery).
- On a 60 Hz display, WindowServer has to composite on the union of their frame times. For example, 20 and 30 fps together is 40 distinct frames a second, where aligned rates (10, 15, 30, all dividing 30) would need at most 30.
- This only matters when several different animated widgets are visible at once.
- **Not changed:** the benefit sits well below WindowServer's ±5 % noise on this Mac, so I couldn't verify it, and changing rates alters how the motion looks. The one-line fix is in the recommendations.

**Sleep and wake:**
- Wallpaper, TapTap and (new) calendar react to sleep, wake and lock notifications.
- The system monitor's loop resumes with one overdue sample; nothing piles up (one `Task`, no queued timers).
- After wake, visible widgets' refresh tasks, the calendar refresh and a stats sample coincide in one short burst. That's acceptable, not a loop.

**Displays connecting or disconnecting:**
- The wallpaper creates or closes a window per screen (`sync()`) and removes that window's occlusion observer. Video players are shared per file and torn down when their last viewer goes (`SharedVideoPlayers.release`).
- Desktop widgets and the island re-lay out on `didChangeScreenParameters`.
- I couldn't physically attach a display during the audit; this is from reading the code.

**Everything visible and hot at once:** the new `PerformancePolicy` makes every subsystem slow down together when the Mac reports `serious` heat, rather than each one keeping its own pace.

---

## Phase 5: final report

### Findings by severity (details and evidence in Phase 2 and Phase 3)

| # | Severity | Finding | Status |
|---|---|---|---|
| F1 | CRITICAL | A closed main window kept its pages alive; its stats request kept the monitor sampling every 2 s forever (0.09 % → 0.89 % CPU) | **fixed**: 0.10 % after close |
| F2 | CRITICAL | Memory built up by the window was never returned (Themes page: +264 MB, kept) | **fixed**: +7 MB, released on close |
| F14 | CRITICAL (was NEEDS VERIFICATION; confirmed in Phase 3) | Covered widgets kept redrawing; a seconds clock cost 12.7 % while hidden | **fixed**: 0.04 % |
| F3 | HIGH | Idle system monitor did a detailed pass every 30 s with no viewer | **fixed**: idle 0.09–0.11 % → 0.03–0.04 % |
| F4 | HIGH | Image caches bounded by count, not bytes; no memory-pressure response | **fixed** |
| F5 | HIGH | No central policy; thermal state ignored | **fixed** (`PerformancePolicy`) |
| F15 | HIGH | A *visible* clock with seconds costs 9–12 % (per-second SwiftUI digit animation) | **not fixed**: needs your decision |
| F6 | MEDIUM | Screenshot undo history unbounded | **fixed**: 24 versions plus the original |
| F7 | MEDIUM | Wallpaper coverage timer ran for still photos | **fixed** |
| F8 | MEDIUM → withdrawn | Neon flicker blur | **measured as nothing** (0.120 % vs 0.131 %); the blur came from the retained window (F1) |
| F9 | LOW | Island warm-up retain cycle | **fixed** (leaks: 0) |
| F10 | LOW | Calendar polled every 5 min | **fixed**: event-driven |
| F11 | LOW | Now Playing 10 s safety poll | kept (2.2 s CPU in 12 h) |
| F12 | LOW | Search page cache unbounded | **fixed**: 200 pages |
| F13 | LOW | Mixer observer token discarded | **fixed** |
| — | LOW | System wallpaper still rewritten every launch | **fixed** (launch 1.71 → 1.59 s CPU) |

### Changes made
All ten are listed in Phase 3 with file, problem, fix, why it helps and tradeoff.

**Files touched:**
- `MainWindow.swift`, `AppServices.swift`, `Components/LiveLayers.swift`, `Studio/ThemePreviews.swift`
- `AllSetCore/Aesthetics/ImageLibrary.swift`, `AllSetCore/Aesthetics/PhotoSearch.swift`
- `AllSetCore/Support/{CostCache, ImageCost, PerformancePolicy}.swift` (new)
- `AllSetCore/System/SystemMonitor.swift`, `AllSetCore/Calendar/CalendarService.swift`
- `Wallpaper/WallpaperController.swift`, `Widgets/WidgetHostView.swift`, `Clipboard/ClipboardMonitor.swift`
- `Widgets/Design/WidgetComponents.swift`, 24 `TimelineView` sites in `Widgets/Kinds/*`, five network widgets
- `Screenshot/ScreenshotStudio.swift`, `Notch/IslandView.swift`, `Notch/NotchController.swift`, `Mixer/MixerController.swift`
- New tests: `CostCacheTests`, `PerformancePolicyTests` (200 tests total).

### Verified vs. estimated

**Measured** (profiler, OS counters, or the app's own probes, on this Mac):
- the F1 CPU numbers;
- the Themes footprint before and after;
- idle CPU of the monitor;
- covered vs. visible clocks;
- the neon flicker's cost;
- leaks before (38 / 4 KB, 1 cycle) and after (0);
- launch CPU;
- idle profile of the real app before and after;
- the combined-load A/B (no difference, within noise);
- the WindowServer A/B at baseline.

**Reasoned, not measured:**
- the thermal tiers (I couldn't make the Mac hot on demand);
- the calendar change;
- the network refresh slowdown;
- sleep/wake and display-change behaviour;
- the frame-rate alignment effect;
- the preview memory per card (read from bytes per row, then confirmed through the footprint numbers).

**Not available:**
- power-rail numbers (`powermetrics` needs sudo);
- per-app WindowServer attribution (only by quit/relaunch A/B, which is noisy while you use the Mac).

**Multi-day stability:** not measured over days. Measured instead:
- the 12 h baseline (106 → 533 MB, peak 790 MB);
- the mechanisms behind it (retained window, unbounded caches), both fixed and verified with open/close cycles.

A 24-hour run of the new build with `footprint` sampled hourly would confirm the trend.

### Remaining risks and recommendations

1. **F15, clock with seconds, visible: 9–12 % CPU. Your decision.** Options:
   - (a) Move the rolling digits to Core Animation. This keeps the look, but the layer has to reproduce every design theme's typography and colour; about a day's work.
   - (b) Let the seconds change without rolling, keeping the roll for minutes. That costs almost nothing, but it's a visible change.
2. **Theme previews drawn from scratch spike memory** (peak 738 MB on a first Themes visit; about 110 MB of allocator high-water stays afterwards).
   - **Cause:** drawing a preview renders a whole desktop of widgets with full-size photos at 16 bits a channel.
   - **Suggested fix:** render previews with photos loaded at preview size (the `ImageLibrary.image(for:maxPixels:)` path) and hand them to the renderer already 8-bit.
   - Needs care to keep previews looking identical; not done.
3. **Launch spikes to 278 MB** while the main window, 11 widget windows and the wallpaper are built together.
   - It's transient and drops to about 100 MB.
   - Staggering widget windows further, or not opening the main window at login, would lower it. The second is a behaviour choice.
4. **Frame-rate alignment** (Phase 4): snap `LiveLayerView.rate(_:)` to {10, 15, 30} and keep art at 15 or 30. Unverified benefit; motion looks slightly different.
5. **Visible widgets' live stats** redraw their SwiftUI cards on every sample (terminal and system widgets every 2 s: the remaining idle main-thread cost, about 0.3 %). Moving live numbers to Core Animation text would cut it; it's the same design question as F15.
6. **Calendar store** (`EKEventStore`) is created at launch even without calendar widgets. It's cheap and didn't show in launch profiles; lazy creation is possible.
7. **The `observe()` helper** captures objects strongly by design. That's safe for app-lifetime objects, but any new short-lived object watched this way will leak (F9 was one). Prefer `[weak …]` captures.

### What was not changed
- **No feature was removed** and no setting was taken away.
- **Visual design is unchanged:**
  - previews and artwork are now 8-bit but look the same (checked with `-renderThemeSets`);
  - covered widgets pause, which nobody can see;
  - uncovered, they resume on the current time.
- **Behaviour changes, deliberate and listed:**
  1. **Undo depth:** the screenshot editor keeps 24 versions plus the original.
  2. **Hot-Mac motion:** decorative motion pauses and limits tighten when the Mac is hot, as they already did in Low Power Mode.
  3. **Slower network refresh:** network widgets refresh 2–4× less often in Low Power Mode or when hot.
  4. **Reopened window:** the main window rebuilds when reopened (same page; transient state like scroll position resets).
  5. **Idle stats:** temperatures and per-app energy refresh only when something shows them.
- **Kept on purpose:** the island animations, clipboard polling, the Now Playing safety poll, and all animation frame rates in the full tier.
