# Second independent audit — 6 October 2026

## Verdict

The next work should be correctness and recovery, not another feature or visual theme. This pass found six defects through isolated executable checks, including failed redaction, replacement of a newly opened screenshot by an old response, and deletion outside managed folders. Passing the existing core tests does not establish safety for these workflows.

This supplements [the first audit](/Users/nawdddep/Downloads/all-set-mac-app-main/Documentation/Reports/2026-10-06-independent-audit.md). No application source was changed. Probes used unchanged copies of the relevant source in `/tmp/allset-deep-review`, minimal substitutes for unrelated dependencies, disposable files, and a delayed mock AI response. No real AI calls, credentials, audio routing, or user files were used. The sanitizer instrumented an isolated GainBox reproduction. Findings marked “source” were traced in code rather than reproduced in the running application. P1 means fix before broader release; P2 means significant correctness or usability debt; P3 means lower-priority efficiency debt.

## Executably confirmed

### 1. P1 — A later blur can undo an earlier redaction

[ScreenshotEdit.swift:119](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/AI/ScreenshotEdit.swift:119)

The renderer draws edits sequentially, but blur reads the original `image`, not the current edited buffer. An overlapping blur therefore paints original-derived content over an existing black redaction. The studio accumulates Claude edits and rerenders them from the base image, so this also applies across requests.

**Probe:** a white image with a redacted rectangle produced a black center pixel `[0,0,0,255]`. Adding an overlapping blur changed that pixel back to `[255,255,255,255]`. This proves the mask is lost; it does not claim every blurred secret becomes fully readable. Redaction must remain authoritative, using a retained final mask or a pipeline that cannot reintroduce original pixels into protected areas.

### 2. P1 — An old AI answer replaces a newly opened screenshot

[ScreenshotStudio.swift:59](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Screenshot/ScreenshotStudio.swift:59), [ask:71](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Screenshot/ScreenshotStudio.swift:71)

`ask` captures a state before awaiting. `load` can replace the document while that request runs, and the completed request then pushes its captured state into the new history. “New Screenshot” and “Open…” remain available during processing. Messages can also land in the wrong conversation.

**Probe:** start a request on a 64-pixel image, load a 128-pixel image while the mocked request waits, and complete the request. Current image width changes from 128 back to 64. Give each document a generation ID, cancel old work, and reject replies whose document no longer matches. Disabling replacement during processing is a possible interim mitigation.

### 3. P1 — The mixer volume handoff has a real data race

[AppAudioTap.swift:23](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Audio/AppAudioTap.swift:23), [callback:178](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Audio/AppAudioTap.swift:178)

`GainBox` is `@unchecked Sendable`, but its target is a normal `UnsafeMutablePointer<Float>`. The UI writes it while the audio callback reads it. A naturally sized 32-bit value does not supply synchronization or establish the required memory semantics.

**Probe:** ThreadSanitizer reported concurrent four-byte reads and writes in the unchanged gain getter/setter. Use an actual lock-free atomic representation or an audio-safe parameter handoff. A blocking mutex in the real-time callback would introduce a different problem.

### 4. P1 — Removing a shelf item can delete an external file

[ShelfStore.swift:60](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Clipboard/ShelfStore.swift:60)

Cleanup decides whether the shelf owns a file with a string prefix. A sibling directory named `Dropped-Other` passes the check for `Dropped`. The shelf otherwise promises to remember external files rather than delete them.

**Probe:** add `Shelf/Dropped-Other/keep.txt`, then remove the shelf entry. The external file was deleted. Track ownership explicitly and validate canonical path components, including a defined policy for symbolic links.

### 5. P1 — Wallpaper catalog paths can delete outside the library

[WallpaperStore.swift:595](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Wallpaper/WallpaperStore.swift:595)

Deletion appends catalog-supplied playback, thumbnail and still paths to the library directory without checking the resolved destination stays inside it. This is a local catalog trust-boundary defect; this audit does not establish an unauthenticated remote exploit.

**Probe:** a catalog item with `playback: "../outside.txt"` loaded successfully. Deleting that item deleted `outside.txt` outside `Library`. Apply one shared path-validation boundary to catalog loading and every file read, write, offload and deletion operation. Validate symlink resolution as well as `..` components.

### 6. P2 — Different health endpoints share the same cache

[StatusService.swift:99](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Developer/StatusService.swift:99)

The cache/in-flight key lowercases the entire address. HTTP paths and query values can be case-sensitive, so one endpoint can inherit another endpoint's status or skip its own request.

**Probe:** `/API/Health?tenant=Alice` and `/api/health?tenant=alice` produced identical keys. Normalize scheme and host while preserving path and query semantics.

## Additional source-backed problems

### 7. P2 — Screenshot undo has a potentially enormous memory budget

[ScreenshotStudio.swift:35](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Screenshot/ScreenshotStudio.swift:35), [retained window:165](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Screenshot/ScreenshotStudio.swift:165)

The limit is 24 edits plus the original, all full-size images. The source itself estimates about 60 MB per 5K image: 25 distinct versions can therefore hold roughly 1.5 GB of pixel data before other overhead. This is an estimate, not measured resident memory; shared references and images without changes cost less. The singleton studio and retained window keep history after closing. Use a byte budget, release on close or explicit session end, and respond to memory pressure.

### 8. P2 — Hiding widgets cancels focus completion

[FocusWidgets.swift:152](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Widgets/Kinds/FocusWidgets.swift:152), [CinematicWidgetFace.swift:166](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Widgets/Kinds/CinematicWidgetFace.swift:166), [DesktopWidgetController.swift:283](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Widgets/DesktopWidgetController.swift:283)

Finishing a focus phase and playing its sound live in SwiftUI `.task` blocks. Hiding widgets removes their windows and replaces pooled roots with an empty root, canceling those tasks. The phase is processed when its view returns; if it is over a minute late, the sound is intentionally skipped. A running timer should belong to a service, with the view observing it. Keeping a covered widget alive is handled; hiding it is a different lifecycle.

### 9. P2 — Workspace restore silently accepts a partial result

[WorkspaceController.swift:41](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Workspace/WorkspaceController.swift:41), [Accessibility.swift:85](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Workspace/Accessibility.swift:85)

Missing apps and failed launches are skipped. Saved state records titles and frames rather than document identifiers, so it cannot recreate missing document windows. It waits up to approximately eight seconds per app for enough windows, then uses what exists. Frame-setting return codes are ignored. It still activates apps and, by default, hides other apps after these failures. Users get no list of what failed or a way to repair it.

Return a per-app/window result, distinguish “layout existing windows” from “restore documents”, verify frame changes, and make hiding others conditional on an acceptable result. Accessibility calls also run synchronously on the main actor, with messaging timeouts; slow target apps can stall the UI. Serial window waits add up beyond their nominal eight-second sleep budget.

### 10. P2 — Saving a new API key can destroy the old working key

[AIImageEditors.swift:53](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/AI/AIImageEditors.swift:53), [GitHub.swift:414](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Developer/GitHub.swift:414), [ScreenshotStudio.swift:424](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Screenshot/ScreenshotStudio.swift:424)

Both setters delete the existing item before adding its replacement. If addition fails, the valid old credential is gone. Screenshot key saving simply returns on failure, with no error feedback. Update an existing keychain item, add only when missing, and surface failures. Clearing a key should remain a separate intentional operation.

### 11. P2 — Weather can look current after repeated refresh failures

[WeatherWidget.swift:21](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Widgets/Kinds/WeatherWidget.swift:21), [Weather.swift:426](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Weather/Weather.swift:426)

Once a cached report exists, the widget renders it instead of the failure state. It shows no fetched timestamp or stale marker. The service filters old cache at startup but does not age out an existing report during a long-running session. Forecast and air-quality fetches also share a failure slot: success in one can erase the other's error. Show useful cached data with an explicit age/error indicator and track errors separately.

### 12. P2 — Ordinary network failures ignore the configured refresh interval

[WidgetComponents.swift:343](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Widgets/Design/WidgetComponents.swift:343), [Weather.swift:426](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Weather/Weather.swift:426), [GitHub.swift:367](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Developer/GitHub.swift:367)

The widget rechecks at least once a minute, even for much longer refresh settings. Services throttle based on the most recent successful fetch. After failure there is no ordinary per-key retry deadline, so offline or invalid-credential requests can recur every minute for every active configuration. GitHub does handle explicit rate limiting. Service fetches are unstructured tasks, so canceling the view's refresh loop does not cancel an in-flight request. Add failure backoff, credential-specific handling and explicit request ownership.

### 13. P2 — GitHub cache survives credential changes without an identity boundary

[GitHub.swift:342](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Developer/GitHub.swift:342), [cache key:354](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Developer/GitHub.swift:354)

Snapshots are persisted as JSON and keyed by widget configuration rather than the authenticated account. Removing or replacing a token does not invalidate that cache. Previously fetched private repository titles and related data can remain visible after credential removal, or temporarily appear under another account. This is local data retention, not evidence of remote access after revocation. Scope caches to credential identity and offer a clear retained-data policy with an explicit purge.

### 14. P2 — Bulk photo import performs expensive processing on the UI thread

[ImageLibrary.swift:212](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Aesthetics/ImageLibrary.swift:212)

The main-actor import method enumerates files and synchronously decodes, scales and JPEG-encodes every image. A dropped folder can contribute 100 images, and multiple folders compound that workload. There is no progress or cancellation in this method. Move processing off the main actor with bounded concurrency, then publish results on it. This pass did not benchmark an actual large import.

### 15. P2 — Small-image loading first pays for a full-image load

[ImageLibrary.swift:326](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSetCore/Aesthetics/ImageLibrary.swift:326)

A thumbnail miss calls the full-size image loader before generating the requested thumbnail from the file. For file-backed sources that unnecessarily decodes the large image first, then performs thumbnail decoding. The full image is subsequently evicted on this path, creating churn. Split file availability/download from image decoding; generate the requested size directly and limit concurrent image work.

### 16. P3 — The app polls the pointer even with no widgets to interact with

[DesktopWidgetController.swift:80](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Widgets/DesktopWidgetController.swift:80)

The pointer timer starts at 20 Hz and remains scheduled when widgets are hidden or the window collection is empty. Early returns reduce the work but do not eliminate wakeups. It does not follow the energy policy used elsewhere. Enable polling only while interaction requires it, or use event-driven tracking where possible. This is an efficiency finding; no battery-drain percentage was measured.

### 17. P2 — Drag snapping can retain a target from another display

[WindowManager.swift:168](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Workspace/WindowManager.swift:168)

A drag's target updates only when its snap-zone enum changes. If consecutive delivered drag events land in the same named zone on different displays, the old target survives. Intermediate non-zone events usually clear it, so this requires that event sequence rather than every display crossing. Include display identity and visible frame in target-change detection. No physical multi-monitor reproduction was performed.

### 18. P2 — Drag-to-snap assumes native tiling exists on every supported OS

[Accessibility.swift:24](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Workspace/Accessibility.swift:24), [WindowManager.swift:138](/Users/nawdddep/Downloads/all-set-mac-app-main/Sources/AllSet/Workspace/WindowManager.swift:138), [Package.swift:6](/Users/nawdddep/Downloads/all-set-mac-app-main/Package.swift:6)

The package supports macOS 14.2. Native edge tiling is treated as enabled when its preference is absent, and that disables All Set's own drag snapping. The source acknowledges native tiling as macOS 15+, but supplies no OS availability check here. Gate by OS version/capability before interpreting the preference. This was established from source; no macOS 14 machine was used.

## What these findings say about the architecture

The most expensive debt is missing ownership boundaries: who owns a file, a screenshot request, a running timer, cached private data, and work after a view disappears. The second problem is silent partial success: launches, accessibility changes, keychain writes and network refreshes can fail while the UI continues as though the operation worked. The third is resource budgeting: counting 24 screenshots or 100 imports does not bound bytes, processing time or concurrent work.

Fix the five P1 findings first, along with the first report's destructive wallpaper workflows. Then move timer completion into a service, add operation results and cancellation/generation checks, and establish byte and concurrency budgets. Add regression tests for these exact failure sequences. More visual polish will not compensate for lost files or an unreliable redaction tool.
