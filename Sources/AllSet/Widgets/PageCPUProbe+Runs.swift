import AllSetCore
import AppKit
import SwiftUI

#if DEBUG

extension PageCPUProbe {

    /// Each widget on the desktop, alone for 20 seconds: which one costs
    /// what, as it runs (visible, animating, with live stats flowing).
    static func runDesktopWidgets(services: AppServices) async {
        func cpuSeconds() -> Double {
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6
        }
        services.monitor.setViewer("probe", visible: true, interval: 2)
        let only = ProcessInfo.processInfo.environment["ONLY_KIND"]
        let widgets = services.widgets.widgets.filter { only == nil || $0.kind.rawValue == only }
        for instance in [WidgetInstance?.none] + widgets.map(Optional.some) {
            let size = instance?.size.dimensions ?? CGSize(width: 170, height: 170)
            let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: size.width, height: size.height), styleMask: [.borderless],
                                  backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            if let instance {
                window.contentView = NSHostingView(rootView: WidgetBody(instance: instance, services: services)
                    .environment(\.widgetIsVisible, true).frame(width: size.width, height: size.height))
            }
            window.orderFrontRegardless()
            try? await Task.sleep(for: .seconds(3))
            let start = cpuSeconds()
            try? await Task.sleep(for: .seconds(Double(ProcessInfo.processInfo.environment["SECONDS"] ?? "20") ?? 20))
            let name = instance.map { "\($0.kind.rawValue) \($0.size.rawValue) \($0.options.clockFace.rawValue)" } ?? "(empty window)"
            print(String(format: "%-28@ %.3f%% CPU", name as NSString, (cpuSeconds() - start) / (Double(ProcessInfo.processInfo.environment["SECONDS"] ?? "20") ?? 20) * 100))
            window.close()
        }
    }

    /// A clock with seconds (a SwiftUI TimelineView ticking every second),
    /// visible and then fully covered by another window: whether SwiftUI
    /// keeps redrawing a window nobody can see.
    static func runCovered(services: AppServices) async {
        func cpuSeconds() -> Double {
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6
        }
        let env = ProcessInfo.processInfo.environment
        var clock = WidgetCatalog.entry(env["ENTRY"] ?? "digitalClock")?.make(size: WidgetSize(rawValue: env["SIZE"] ?? "medium") ?? .medium)
            ?? WidgetInstance(kind: .clock)
        clock.options.showSeconds = true
        let frame = NSRect(x: 300, y: 300, width: 364, height: 170)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        // Wired like a desktop widget window: on screen unless occluded.
        let state = ProbeOcclusion()
        window.contentView = NSHostingView(rootView: ProbeOccludedWidget(instance: clock, services: services, state: state)
            .frame(width: 364, height: 170))
        let observer = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window,
                                                              queue: .main) { _ in
            MainActor.assumeIsolated { state.isOccluded = !window.occlusionState.contains(.visible) }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        window.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(3))
        var start = cpuSeconds()
        try? await Task.sleep(for: .seconds(30))
        print(String(format: "clock visible: %.3f%% CPU", (cpuSeconds() - start) / 30 * 100))
        let cover = NSWindow(contentRect: frame.insetBy(dx: -40, dy: -40), styleMask: [.borderless], backing: .buffered, defer: false)
        cover.isReleasedWhenClosed = false
        cover.backgroundColor = .gray
        cover.isOpaque = true
        cover.level = .floating
        cover.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(3))
        print("clock window occluded: \(!window.occlusionState.contains(.visible))")
        start = cpuSeconds()
        try? await Task.sleep(for: .seconds(30))
        print(String(format: "clock covered: %.3f%% CPU", (cpuSeconds() - start) / 30 * 100))
        cover.close()
        window.close()
    }

    /// The wallpaper library at scale: 1,008 entries (the real ones repeated,
    /// each with its own thumbnail file) in the real main window, scrolled end
    /// to end, five wallpaper switches, then closed; five cycles. Then the
    /// pausing rules: Low Power Mode and a window covering the screen.
    /// Leaves the saved wallpaper as it found it.
    static func runWallpaperLibrary(services: AppServices) async {
        func cpuSeconds() -> Double {
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6
        }
        func report(_ label: String) {
            print(String(format: "%-26@ %4.0f MB  %@; %@", label as NSString, footprintMB(), services.images.debugCacheReport,
                         SharedVideoPlayers.debugReport))
        }
        let store = services.wallpaper
        let original = store.config
        var quiet = original
        // No system-wallpaper stills while probing, and no personal server:
        // the synthetic entries share real playback paths, and with the
        // library offloaded they'd download real files into it.
        quiet.matchSystemWallpaper = false
        quiet.libraryServerURL = nil
        store.config = quiet
        try? await Task.sleep(for: .seconds(3))
        let real = store.library
        guard !real.isEmpty else { print("no library imported"); store.config = original; return }
        // Every synthetic entry gets its own thumbnail file, so the cache is
        // tested with as many distinct pictures as entries.
        let thumbs = store.libraryDirectory.appendingPathComponent("probe-thumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: thumbs, withIntermediateDirectories: true)
        var videos: [LibraryVideo] = []
        for copy in 0..<21 {
            for video in real {
                var entry = video
                entry.id = "\(video.id)-\(copy)"
                entry.title = copy == 0 ? video.title : "\(video.title) \(copy + 1)"
                if let source = store.libraryThumbnailURL(video) {
                    let name = "probe-thumbs/\(entry.id).jpg"
                    try? FileManager.default.copyItem(at: source, to: store.libraryDirectory.appendingPathComponent(name))
                    entry.thumbnail = name
                }
                videos.append(entry)
            }
        }
        store.debugReplaceLibrary(videos)
        print("library entries: \(videos.count)")
        print("first resolves to: \(store.libraryURL(videos[0].id)?.lastPathComponent ?? "nil"); roots \(store.libraryRoots.count), reachable \(store.reachableRoots.count)")
        print("wallpaper enabled: \(store.config.isEnabled); wallpaper windows: \(NSApp.windows.filter { $0.level.rawValue < 0 }.count)")
        report("before")
        let mainWindow = { NSApp.windows.first { $0.frameAutosaveName == "AllSetMain" && $0.isVisible } }
        for cycle in 1...5 {
            services.ui.page = .wallpaper
            MainWindowController.shared.show(services: services)
            try? await Task.sleep(for: .seconds(3))
            report("cycle \(cycle) open")
            if let scroll = Self.tallestScrollView(in: mainWindow()?.contentView) {
                final class Gaps: @unchecked Sendable { var last = CACurrentMediaTime(); var worst = 0.0; var lost = 0.0 }
                let gaps = Gaps()
                let timer = Timer(timeInterval: 0.004, repeats: true) { _ in
                    let now = CACurrentMediaTime(), gap = now - gaps.last
                    if gap > 0.017 { gaps.lost += gap - 0.004 }
                    gaps.worst = max(gaps.worst, gap)
                    gaps.last = now
                }
                RunLoop.main.add(timer, forMode: .common)
                let start = cpuSeconds(), began = Date()
                var y: CGFloat = 0
                while y < (scroll.documentView?.frame.height ?? 0) {
                    y += 700
                    scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
                    scroll.reflectScrolledClipView(scroll.contentView)
                    try? await Task.sleep(for: .milliseconds(120))
                }
                let elapsed = Date().timeIntervalSince(began)
                timer.invalidate()
                print(String(format: "  scrolled %.0f pt in %.1f s: %.1f%% CPU; main thread: longest stall %.0f ms, %.0f ms lost",
                             y, elapsed, (cpuSeconds() - start) / elapsed * 100, gaps.worst * 1000, gaps.lost * 1000))
            }
            report("cycle \(cycle) scrolled")
            for video in videos.shuffled().prefix(5) {
                store.set(.library(video.id))
                try? await Task.sleep(for: .seconds(1.5))
            }
            print("  after switching: source \(store.config.source), playing \(services.ui.wallpaperPlaying), \(SharedVideoPlayers.debugReport)")
            if cycle == 1 {
                func names(_ view: NSView, _ depth: Int = 0) -> [String] {
                    guard depth < 12 else { return [] }
                    return ["\(type(of: view))"] + view.subviews.flatMap { names($0, depth + 1) }
                }
                let test = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 480, height: 300), styleMask: [.borderless],
                                    backing: .buffered, defer: false)
                test.isReleasedWhenClosed = false
                test.contentView = NSHostingView(rootView: WallpaperView(config: store.config, services: services)
                    .environment(\.widgetIsVisible, true).frame(width: 480, height: 300))
                test.orderFrontRegardless()
                try? await Task.sleep(for: .seconds(1))
                print("  fresh WallpaperView subviews: \(names(test.contentView ?? NSView()).prefix(6).joined(separator: ", ")); \(SharedVideoPlayers.debugReport)")
                test.close()
                for window in NSApp.windows where window.level.rawValue < 0 {
                    print("  wallpaper window \(window.frame) visible \(window.isVisible) occluded \(!window.occlusionState.contains(.visible))")
                    print("  views: " + names(window.contentView ?? NSView()).filter { !$0.contains("Hosting") || true }.prefix(12).joined(separator: ", "))
                }
            }
            report("cycle \(cycle) switched x5")
            mainWindow()?.performClose(nil)
            try? await Task.sleep(for: .seconds(4))
            report("cycle \(cycle) closed")
        }
        // The same pausing rules as every wallpaper. Covered (this Mac's
        // windows usually cover the desktop) it rests; then with covering
        // ignored, Low Power Mode must still stop it.
        let policy = services.ui.performance
        print("covered by windows -> playing: \(services.ui.wallpaperPlaying) (\(SharedVideoPlayers.debugReport))")
        var uncovered = store.config
        uncovered.pauseWhenCovered = false
        store.config = uncovered
        try? await Task.sleep(for: .seconds(2))
        print("covering ignored -> playing: \(services.ui.wallpaperPlaying)")
        services.ui.performance = PerformancePolicy(isLowPower: true)
        try? await Task.sleep(for: .seconds(1))
        print("Low Power Mode -> playing: \(services.ui.wallpaperPlaying)")
        services.ui.performance = policy
        try? await Task.sleep(for: .seconds(1))
        print("back to normal -> playing: \(services.ui.wallpaperPlaying)")
        let frame = NSScreen.main?.frame ?? .zero
        let cover = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        cover.isReleasedWhenClosed = false
        cover.backgroundColor = .darkGray
        cover.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(4))
        print("screen covered -> playing: \(services.ui.wallpaperPlaying)")
        cover.close()
        try? await Task.sleep(for: .seconds(4))
        print("uncovered -> playing: \(services.ui.wallpaperPlaying)")
        store.config = original
        try? await Task.sleep(for: .seconds(2))
        report("wallpaper restored")
        try? FileManager.default.removeItem(at: thumbs)
    }

    /// The scroll view with the most to scroll (a page, not the sidebar).
    static func tallestScrollView(in view: NSView?) -> NSScrollView? {
        var best: NSScrollView?
        func visit(_ view: NSView) {
            if let scroll = view as? NSScrollView, (scroll.documentView?.frame.height ?? 0) > (best?.documentView?.frame.height ?? 0) {
                best = scroll
            }
            view.subviews.forEach(visit)
        }
        if let view { visit(view) }
        return best
    }

    /// The spiral, charms, label and the mystic widgets.
    static func runMystic(services: AppServices) async {
        func widget(_ entry: String, _ size: WidgetSize) -> AnyView {
            let instance = WidgetCatalog.entry(entry)?.make(size: size) ?? WidgetInstance(kind: .clock)
            return AnyView(WidgetBody(instance: instance, services: services).environment(\.widgetIsVisible, true))
        }
        await run(pages: [], views: [
            ("spiral", widget("spiral", .medium)), ("chrome heart", widget("chromeHeart", .small)),
            ("perfume label", widget("perfumeLabel", .medium)), ("aura", widget("aura", .medium)),
            ("tarot", widget("tarot", .medium)), ("zodiac", widget("zodiac", .medium)),
            ("magic ball", widget("eightBall", .medium)), ("candle", widget("candle", .medium)),
        ], services: services)
    }

    static func runWidgets(services: AppServices) async {
        func widget(_ kind: WidgetKind, _ size: WidgetSize = .small, change: (inout WidgetInstance) -> Void = { _ in }) -> AnyView {
            var instance = WidgetInstance(kind: kind, size: size)
            change(&instance)
            return AnyView(WidgetBody(instance: instance, services: services)
                .environment(\.widgetIsVisible, true)
                .environment(\.artFrameLimit, 24))
        }
        await run(pages: [], views: [
            ("calendar mesh", widget(.calendar)),
            ("calendar still", widget(.calendar) { $0.options.animateArt = false }),
            ("ambient art", widget(.ambient, .medium)),
            ("ambient battery", AnyView(WidgetBody(instance: WidgetInstance(kind: .ambient, size: .medium), services: services)
                .environment(\.widgetIsVisible, true)
                .environment(\.artFrameLimit, 15))),
            ("clock photo", widget(.clock, .medium)),
            ("daylight", widget(.daylight, .medium)),
            ("polaroids", widget(.polaroids, .medium)),
            ("system", widget(.system)),
            ("vinyl", widget(.vinyl, .medium)),
            ("now playing", widget(.nowPlaying, .medium)),
            ("todo", widget(.todo, .large)),
            ("focus idle", widget(.focus, .medium)),
            ("focus running", widget(.focus, .medium) { $0.options.focus.start(at: .now, focusMinutes: 25, breakMinutes: 5) }),
            ("stopwatch idle", widget(.stopwatch)),
            ("stopwatch running", widget(.stopwatch) { $0.options.stopwatch.start(at: .now) }),
            ("flip clock", widget(.clock, .medium) { $0.options.clockFace = .flip }),
            ("frosted clock", widget(.clock, .medium) { $0 = WidgetTheme.pinkLatte.styled($0) }),
            ("shortcuts", widget(.shortcuts, .medium)),
            ("sticker", widget(.sticker, .medium)),
            ("scene clouds", widget(.ambient, .medium) { $0.options.art = ArtPiece(style: .clouds, palette: .sky) }),
            ("scene hearts", widget(.ambient, .medium) { $0.options.art = ArtPiece(style: .hearts, palette: .coquette) }),
            ("scene leopard", widget(.ambient, .medium) { $0.options.art = ArtPiece(style: .leopard, palette: .diva) }),
            ("scene film", widget(.ambient, .medium) { $0.options.art = ArtPiece(style: .film, palette: .mocha) }),
            ("scene skyline", widget(.ambient, .medium) { $0.options.art = ArtPiece(style: .skyline, palette: .shadow) }),
            ("scene embers", widget(.ambient, .medium) { $0.options.art = ArtPiece(style: .embers, palette: .ember) }),
            ("neon sign", widget(.neon, .medium)),
            ("terminal", widget(.terminal, .medium)),
            ("dots", widget(.dots, .large)),
            ("film strip", widget(.photo, .medium) { $0.options.photoFrame = .filmStrip }),
            ("liquid glass clock", widget(.clock, .medium) { $0.options.clockFace = .minimal; $0.options.designTheme = "liquidGlass" }),
            ("native cpu", widget(.metric, .medium) { $0.options.designTheme = "native" }),
            ("native memory", widget(.metric, .medium) { $0.options.metric = .memory; $0.options.designTheme = "native" }),
            ("wifi", widget(.metric, .medium) { $0.options.metric = .wifi }),
            ("world clock", widget(.clock, .medium) { $0.options.clockFace = .world }),
            ("goals", widget(.goals, .medium)),
            ("habits", widget(.habits, .medium)),
            ("status", widget(.status, .medium)),
            ("github", widget(.github, .medium) { $0.options.github.user = "torvalds" }),
            ("editorial date", widget(.date, .medium) { $0.options.designTheme = "editorial" }),
        ], services: services)
    }

    /// Scrolls the busiest pages of the real main window up and down, a
    /// step every frame, and reports how often the main thread missed a
    /// frame: the smoothness a person feels, as numbers CI can compare.
    static func runScroll(services: AppServices) async {
        // A nearly invisible accessory app gets App Nap: its timers coalesce
        // and every "frame" looks late though nothing is busy. Hold it off.
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical],
                                                             reason: "Measuring scroll smoothness")
        defer { ProcessInfo.processInfo.endActivity(activity) }
        let window = NSWindow(contentRect: NSRect(x: 40, y: 40, width: 1280, height: 800),
                              styleMask: [.titled, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        MainWindowController.dress(window)
        window.alphaValue = 0.01
        window.ignoresMouseEvents = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        let controller = MainWindowController.contentController(services: services)
        window.contentViewController = controller
        window.setContentSize(NSSize(width: 1280, height: 800))
        window.orderFrontRegardless()
        // The real window's relief from AppKit's per-frame drag-region bookkeeping
        // (`ScrollingWindowRelief`); `NORELIEF=1` leaves it out, for comparing.
        let relief = ScrollingWindowRelief()
        if ProcessInfo.processInfo.environment["NORELIEF"] == nil { relief.attach(to: window) }
        defer { relief.stop() }
        // Each page twice: the first pass pays for first sight (previews
        // drawn, tiles made); the second is what scrolling feels like after.
        let onlyScroll = ProcessInfo.processInfo.environment["ONLY"]
        // Wheel/scrollbar movement doesn't necessarily emit trackpad live-scroll
        // notifications. Exercise the bounds observer used by those inputs too.
        let sendsLiveNotifications = ProcessInfo.processInfo.environment["SCROLL_INPUT"] != "wheel"
        // `STALL_MS=22` lists every frame slower than that with where the
        // page was, to find what on a page costs a frame.
        let stall = (Double(ProcessInfo.processInfo.environment["STALL_MS"] ?? "") ?? 100) / 1000
        for (name, page) in [("themes", AppPage.themes), ("gallery", .gallery(nil)), ("wallpaper", .wallpaper)]
            .flatMap({ [($0.0 + " 1st", $0.1), ($0.0 + " 2nd", $0.1)] }) {
            if let onlyScroll, !name.hasPrefix(onlyScroll) { continue }
            if services.ui.page != page {
                services.ui.page = page
                try? await Task.sleep(for: .seconds(5))
            }
            guard let scroll = tallestScrollView(in: window.contentView), let document = scroll.documentView else {
                print(String(format: "scroll %-10@ no scroll view", name as NSString))
                continue
            }
            let clip = scroll.contentView
            let range = max(document.frame.height - clip.bounds.height, 0)
            var y: CGFloat = 0, step: CGFloat = 24
            var gaps: [Double] = []
            // What a trackpad scroll announces, so work that waits for
            // scrolling to stop sees this one.
            if sendsLiveNotifications {
                NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: scroll)
            }
            let cpu = cpuSeconds(), begin = CACurrentMediaTime()
            var last = begin
            while CACurrentMediaTime() - begin < 6 {
                y += step
                if y > range || y < 0 { step = -step; y = min(max(y, 0), range) }
                clip.scroll(to: NSPoint(x: 0, y: y))
                scroll.reflectScrolledClipView(clip)
                // A trackpad scroll says so on every step.
                if sendsLiveNotifications {
                    NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: scroll)
                }
                try? await Task.sleep(for: .milliseconds(16))
                let now = CACurrentMediaTime()
                gaps.append(now - last)
                if now - last > stall { print(String(format: "  stall %.0f ms at y=%.0f of %.0f", (now - last) * 1000, y, range)) }
                last = now
            }
            let seconds = CACurrentMediaTime() - begin
            if sendsLiveNotifications {
                NotificationCenter.default.post(name: NSScrollView.didEndLiveScrollNotification, object: scroll)
            }
            gaps.sort()
            let p95 = gaps[min(gaps.count - 1, Int(Double(gaps.count) * 0.95))] * 1000
            print(String(format: "scroll %-10@ %5.1f%% CPU  frames %3d  p50 %4.1f ms  p95 %5.1f ms  max %5.1f ms  hitches(>33ms) %d  range %.0f pt",
                         name as NSString, (cpuSeconds() - cpu) / seconds * 100, gaps.count,
                         gaps[gaps.count / 2] * 1000, p95, (gaps.last ?? 0) * 1000,
                         gaps.filter { $0 > 0.033 }.count, range))
            clip.scroll(to: .zero)
            // The window must be movable again the moment a scroll ends, and, for a
            // scroll that never says it ended, shortly after it last moved.
            let afterEnd = window.isMovable
            NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: scroll)
            let during = window.isMovable
            try? await Task.sleep(for: .seconds(1))
            print("  window movable: after the scroll \(afterEnd), mid-scroll \(during), 1 s after an unfinished scroll \(window.isMovable)")
        }
        window.close()
    }

    /// Switches the real window between pages, a cold mount each time, and
    /// reports how long the main thread was held: what a click on a tab feels like.
    static func runPageSwitch(services: AppServices) async {
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical],
                                                             reason: "Measuring page switches")
        defer { ProcessInfo.processInfo.endActivity(activity) }
        let window = NSWindow(contentRect: NSRect(x: 40, y: 40, width: 1280, height: 800),
                              styleMask: [.titled, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        MainWindowController.dress(window)
        window.alphaValue = 0.01
        window.ignoresMouseEvents = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        let controller = MainWindowController.contentController(services: services)
        window.contentViewController = controller
        window.setContentSize(NSSize(width: 1280, height: 800))
        window.orderFrontRegardless()
        services.ui.page = .about
        try? await Task.sleep(for: .seconds(2))
        let pages: [(String, AppPage)] = [("island", .island), ("favorites", .favorites), ("themes", .themes), ("gallery", .gallery(nil)), ("wallpaper", .wallpaper),
                                          ("desktop", .desktop), ("monitor", .monitor), ("mixer", .mixer), ("notes", .notes), ("general", .general)]
        let only = ProcessInfo.processInfo.environment["ONLY"]
        let repeats = Int(ProcessInfo.processInfo.environment["REPEAT"] ?? "") ?? 1
        for pass in (["1st", "2nd"] + Array(repeating: "again", count: max(repeats - 1, 0))) {
            for (name, page) in pages where only == nil || only == name {
                var gaps: [Double] = []
                let start = CACurrentMediaTime()
                var last = start
                services.ui.page = page
                while CACurrentMediaTime() - start < 1.5 {
                    try? await Task.sleep(for: .milliseconds(4))
                    let now = CACurrentMediaTime()
                    gaps.append(now - last)
                    last = now
                }
                let held = gaps.filter { $0 > 0.02 }.reduce(0, +)
                print(String(format: "switch %@ %-10@ worst %6.1f ms  frames missed(>20ms) %2d  held %6.1f ms", pass as NSString, name as NSString,
                             (gaps.max() ?? 0) * 1000, gaps.filter { $0 > 0.02 }.count, held * 1000))
                services.ui.page = .about
                try? await Task.sleep(for: .milliseconds(700))
            }
        }
        window.close()
    }

    /// How long a Gallery card takes to appear, whole and part by part:
    /// what scrolling the Gallery pays for each new card.
    static func runGalleryParts(services: AppServices) async {
        try? await Task.sleep(for: .seconds(2))
        let entries = Array(WidgetCatalog.entries.prefix(12))
        let chipTitles = ["Photo", "Solid", "Frosted", "Outline", "Mesh", "Glass", "Art", "No Card", "Color", "Dark"]
        func chips() -> some View {
            HStack(spacing: 6) {
                ForEach(chipTitles, id: \.self) { title in
                    Text(title).font(.system(size: 11, weight: .semibold)).padding(.horizontal, 9).frame(height: 22)
                        .background(Capsule().fill(.white.opacity(0.08)))
                }
            }
        }
        let parts: [(String, CGSize, (CatalogEntry) -> AnyView)] = [
            ("card", CGSize(width: 320, height: 380), { AnyView(GalleryCard(entry: $0, services: services)) }),
            ("backdrop", CGSize(width: 300, height: 220), { _ in AnyView(StudioBackdrop()) }),
            ("widget", CGSize(width: 300, height: 220), {
                AnyView(WidgetPreview(instance: $0.make(), services: services, fit: CGSize(width: 250, height: 190)))
            }),
            ("size picker", CGSize(width: 120, height: 30), { entry in
                AnyView(Picker("Size", selection: .constant(entry.defaultSize)) {
                    ForEach(entry.sizes) { Text($0.shortTitle).tag($0) }
                }.pickerStyle(.segmented).labelsHidden().fixedSize())
            }),
            ("chips in scroll", CGSize(width: 300, height: 30), { _ in AnyView(ScrollView(.horizontal, showsIndicators: false) { chips() }) }),
            ("chips plain", CGSize(width: 300, height: 30), { _ in AnyView(chips().frame(width: 300, alignment: .leading).clipped()) }),
            ("add button", CGSize(width: 300, height: 40), { _ in
                AnyView(Button {} label: { Label("Add to Desktop", systemImage: "plus").frame(maxWidth: .infinity) }.buttonStyle(.pillProminent))
            }),
        ]
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 400), styleMask: [.borderless], backing: .buffered, defer: false)
        window.alphaValue = 0.01
        window.orderFrontRegardless()
        for (name, size, make) in parts {
            var times: [Double] = []
            for entry in entries {
                let start = CACurrentMediaTime()
                let host = NSHostingView(rootView: make(entry).environment(\.colorScheme, .dark))
                host.frame = CGRect(origin: .zero, size: size)
                window.contentView = host
                host.layoutSubtreeIfNeeded()
                host.displayIfNeeded()
                CATransaction.flush()
                times.append(CACurrentMediaTime() - start)
                try? await Task.sleep(for: .milliseconds(30))
            }
            times.sort()
            print(String(format: "gallery part %-16@ median %6.1f ms  worst %6.1f ms", name as NSString,
                         times[times.count / 2] * 1000, (times.last ?? 0) * 1000))
        }
        window.close()
    }
}

#endif
