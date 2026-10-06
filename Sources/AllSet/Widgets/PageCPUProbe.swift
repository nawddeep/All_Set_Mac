#if DEBUG
import AllSetCore
import AppKit
import SwiftUI

/// Shows main-window pages (or single views) one at a time in a nearly
/// invisible window and reports the CPU each uses while nothing happens, to
/// catch views that keep redrawing when they should be idle.
@MainActor
enum PageCPUProbe {
    static func run(pages: [(String, AppPage)], views: [(String, AnyView)] = [], services: AppServices) async {
        try? await Task.sleep(for: .seconds(2))
        await measure("no window", seconds: 5)
        // Live stats every second, with nothing drawing them.
        services.monitor.setViewer("probe", visible: true)
        await measure("sampling", seconds: 5)

        let window = NSWindow(contentRect: NSRect(x: 40, y: 40, width: 1120, height: 760),
                              styleMask: [.titled, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.alphaValue = 0.01
        window.ignoresMouseEvents = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()

        for (name, view) in views {
            window.contentViewController = NSHostingController(rootView: view)
            try? await Task.sleep(for: .seconds(2))
            await measure(name, seconds: 5)
        }
        if !pages.isEmpty {
            window.contentViewController = MainWindowController.contentController(services: services)
            for (name, page) in pages {
                services.ui.page = page
                try? await Task.sleep(for: .seconds(3))
                await measure(name, seconds: 6)
            }
        }
        window.close()
    }

    static func runIslandViews(services: AppServices) async {
        let model = NotchViewModel(geometry: NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 940, height: 340),
                                                           safeAreaTop: 32, topLeftArea: nil, topRightArea: nil, menuBarHeight: 32))
        model.isExpanded = true
        await run(pages: [], views: [
            ("audio bars", AnyView(AudioBars(isPlaying: true, color: .white).frame(width: 40, height: 20))),
            ("home tab", AnyView(HomeTab(services: services).frame(width: 600, height: 170))),
            ("now playing", AnyView(NowPlayingCard(media: services.media).frame(width: 300, height: 170))),
            ("expanded panel", AnyView(ExpandedPanel(model: model, services: services, openSettings: {}).frame(width: 640, height: 200))),
            ("notch root", AnyView(NotchRootView(model: model, services: services, expand: {}, openSettings: {}))),
            ("system tab", AnyView(SystemTab(services: services).frame(width: 816, height: 244))),
            ("top apps", AnyView(TopAppsCard(services: services).frame(width: 216, height: 244))),
        ], services: services)
    }

    static func runWallpapers(services: AppServices) async {
        func wallpaper(_ style: ArtStyle, fps: Int, sharp: Bool = false) -> AnyView {
            var config = WallpaperConfig()
            config.source = .art(ArtPiece(style: style, palette: .aurora))
            config.frameRate = fps
            config.sharpArt = sharp
            return AnyView(WallpaperView(config: config, services: services)
                .environment(\.widgetIsVisible, true)
                .frame(width: 1470, height: 956))
        }
        await run(pages: [], views: [
            ("photo drift", {
                var config = WallpaperConfig()
                config.source = .photo(.web(CuratedBackgrounds.suggestion(3)))
                config.motion = .drift
                return AnyView(WallpaperView(config: config, services: services)
                    .environment(\.widgetIsVisible, true)
                    .frame(width: 1470, height: 956))
            }()),
            ("blobs 30", wallpaper(.blobs, fps: 30)),
            ("aurora 30", wallpaper(.aurora, fps: 30)),
            ("aurora 60", wallpaper(.aurora, fps: 60)),
            ("aurora 30 sharp", wallpaper(.aurora, fps: 30, sharp: true)),
            ("blobs 30 again", wallpaper(.blobs, fps: 30)),
            ("sunset 30", wallpaper(.sunset, fps: 30)),
            ("dunes 30", wallpaper(.dunes, fps: 30)),
            ("skyline 30", wallpaper(.skyline, fps: 30)),
            ("skyline 30 sharp", wallpaper(.skyline, fps: 30, sharp: true)),
            ("embers 30", wallpaper(.embers, fps: 30)),
            ("leopard 30", wallpaper(.leopard, fps: 30)),
            ("hearts 30", wallpaper(.hearts, fps: 30)),
            ("clouds 30", wallpaper(.clouds, fps: 30)),
            ("film 30", wallpaper(.film, fps: 30)),
        ], services: services)
    }

    /// What the window server spends compositing a full desktop of live
    /// widgets: the Seven world moving, then paused, three times over, so the
    /// difference stands out from whatever else the Mac is doing.
    static func runWindowServer(services: AppServices) async {
        let seven = ThemeLibrary.set("setup.seven")!
        let widgets = seven.widgets(screenName: nil, bounds: CGSize(width: 1136, height: 768))
        let window = NSWindow(contentRect: NSRect(x: 40, y: 40, width: 1136, height: 768),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.alphaValue = 0.01
        window.ignoresMouseEvents = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        func show(moving: Bool) {
            window.contentViewController = NSHostingController(rootView: ZStack(alignment: .topLeading) {
                ForEach(widgets) { widget in
                    WidgetBody(instance: widget, services: services).offset(x: widget.offset.x, y: widget.offset.y)
                }
            }
            .frame(width: 1136, height: 768, alignment: .topLeading)
            .environment(\.widgetIsVisible, moving))
        }
        window.orderFrontRegardless()
        for round in 1...3 {
            for moving in [true, false] {
                show(moving: moving)
                try? await Task.sleep(for: .seconds(3))
                let server = windowServerSeconds(), own = cpuSeconds()
                try? await Task.sleep(for: .seconds(8))
                print(String(format: "round %d %-7@  window server %5.1f%%  app %4.1f%%", round, (moving ? "moving" : "paused") as NSString,
                             (windowServerSeconds() - server) / 8 * 100, (cpuSeconds() - own) / 8 * 100))
            }
        }
        window.close()
    }

    /// Applies a whole theme (into the scratch layout from `-widgetsFile`) and
    /// reports the longest the main thread went without running a 4 ms timer:
    /// the hitch someone would feel.
    static func runApply(services: AppServices) async {
        final class Gaps: @unchecked Sendable { var last = CACurrentMediaTime(); var worst = 0.0; var total = 0.0 }
        try? await Task.sleep(for: .seconds(3))
        for id in ["setup.seven", "setup.americana", "setup.wonderkid"] {
            guard let set = ThemeLibrary.set(id) else { continue }
            let gaps = Gaps()
            let timer = Timer(timeInterval: 0.004, repeats: true) { _ in
                let now = CACurrentMediaTime()
                let gap = now - gaps.last
                if gap > 0.017 { gaps.total += gap - 0.004 }
                gaps.worst = max(gaps.worst, gap)
                gaps.last = now
            }
            RunLoop.main.add(timer, forMode: .common)
            let start = CACurrentMediaTime()
            services.install(set, mode: .replace, wallpaper: false)
            let call = CACurrentMediaTime() - start
            try? await Task.sleep(for: .seconds(4))
            timer.invalidate()
            print(String(format: "%-18@ install call %4.0f ms, longest hitch %4.0f ms, frames lost %4.0f ms", set.name as NSString,
                         call * 1000, gaps.worst * 1000, gaps.total * 1000))
        }
    }

    /// Shows a whole world of live widgets at once, visible, and reports the
    /// longest main-thread hitch while their artwork is drawn.
    static func runReveal(services: AppServices) async {
        final class Gaps: @unchecked Sendable { var last = CACurrentMediaTime(); var worst = 0.0; var total = 0.0 }
        let window = NSWindow(contentRect: NSRect(x: 40, y: 40, width: 1136, height: 768),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.alphaValue = 0.01
        window.ignoresMouseEvents = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(2))
        for id in ["setup.seven", "setup.wonderkid", "setup.americana", "setup.seven"] {
            guard let set = ThemeLibrary.set(id) else { continue }
            let widgets = set.widgets(screenName: nil, bounds: CGSize(width: 1136, height: 768))
            let gaps = Gaps()
            let timer = Timer(timeInterval: 0.004, repeats: true) { _ in
                let now = CACurrentMediaTime()
                let gap = now - gaps.last
                if gap > 0.017 { gaps.total += gap - 0.004 }
                gaps.worst = max(gaps.worst, gap)
                gaps.last = now
            }
            RunLoop.main.add(timer, forMode: .common)
            window.contentViewController = NSHostingController(rootView: ZStack(alignment: .topLeading) {
                ForEach(widgets) { widget in
                    WidgetBody(instance: widget, services: services).offset(x: widget.offset.x, y: widget.offset.y)
                }
            }
            .frame(width: 1136, height: 768, alignment: .topLeading)
            .environment(\.widgetIsVisible, true))
            try? await Task.sleep(for: .seconds(3))
            timer.invalidate()
            print(String(format: "%-14@ longest hitch %4.0f ms, frames lost %4.0f ms", set.name as NSString, gaps.worst * 1000, gaps.total * 1000))
        }
        window.close()
    }

    /// The island in a real window: opens it, switches tabs and closes it,
    /// reporting the longest main-thread hitch and frames lost for each step.
    static func runIslandMotion(services: AppServices) async {
        final class Gaps: @unchecked Sendable { var last = CACurrentMediaTime(); var worst = 0.0; var total = 0.0 }
        let model = NotchViewModel(geometry: NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 940, height: 340),
                                                           safeAreaTop: 32, topLeftArea: nil, topRightArea: nil, menuBarHeight: 32))
        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 940, height: 340),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.alphaValue = 0.01
        window.ignoresMouseEvents = true
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.contentView = IslandView(model: model, root: NotchRootView(model: model, services: services, expand: {}, openSettings: {}))
        window.orderFrontRegardless()
        services.monitor.setViewer("probe", visible: true)
        try? await Task.sleep(for: .seconds(3))
        if ProcessInfo.processInfo.environment["COLD"] == nil {
            await IslandView.warmUp(geometry: model.geometry, services: services)
            try? await Task.sleep(for: .seconds(1))
        }
        func step(_ name: String, _ change: @MainActor () -> Void) async {
            let gaps = Gaps()
            let timer = Timer(timeInterval: 0.004, repeats: true) { _ in
                let now = CACurrentMediaTime()
                let gap = now - gaps.last
                if gap > 0.017 { gaps.total += gap - 0.004 }
                gaps.worst = max(gaps.worst, gap)
                gaps.last = now
            }
            RunLoop.main.add(timer, forMode: .common)
            change()
            try? await Task.sleep(for: .milliseconds(1200))
            timer.invalidate()
            print(String(format: "%-20@ longest hitch %4.0f ms, frames lost %4.0f ms", name as NSString, gaps.worst * 1000, gaps.total * 1000))
        }
        for round in 1...2 {
            await step("open \(round)") { withAnimation(NotchAnimation.open) { model.isExpanded = true } }
            await step("home → system \(round)") { withAnimation(NotchAnimation.tab) { model.tab = .system } }
            await step("system → home \(round)") { withAnimation(NotchAnimation.tab) { model.tab = .home } }
            await step("home → mixer \(round)") { withAnimation(NotchAnimation.tab) { model.tab = .mixer } }
            await step("mixer → system \(round)") { withAnimation(NotchAnimation.tab) { model.tab = .system } }
            await step("close \(round)") { withAnimation(NotchAnimation.close) { model.isExpanded = false } }
            model.tab = .home
        }
        window.close()
    }

    /// Real searches through both sources: how many results, from where, how fast.
    static func runSearch(services: AppServices) async {
        let search = PhotoSearch(cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("probe-search-\(UUID())"))
        for text in ["iron man", "jjk", "lambo", "anime", "coquette", "mountains", "naurto", "batman -lego", "gta 6", "dark academia"] {
            let start = CACurrentMediaTime()
            search.search(text, immediately: true)
            while search.results.isEmpty, search.errorMessage == nil, CACurrentMediaTime() - start < 25 {
                try? await Task.sleep(for: .milliseconds(100))
                if !search.isSearching, CACurrentMediaTime() - start > 3 { break }
            }
            let sources = Dictionary(grouping: search.results, by: { $0.provider ?? "?" }).mapValues(\.count)
            print(String(format: "%-16@ %3d results in %4.1f s %@ more:%@ %@ %@", text as NSString, search.results.count,
                         CACurrentMediaTime() - start, sources.description as NSString, search.hasMore ? "yes" : "no",
                         (search.interpretation ?? "") as NSString, (search.errorMessage ?? "") as NSString))
        }
    }

    /// WindowServer's CPU time so far, from `ps` (which may read other users' processes).
    private static func windowServerSeconds() -> Double {
        let find = Process(), read = Pipe()
        find.executableURL = URL(fileURLWithPath: "/bin/ps")
        find.arguments = ["-axo", "cputime=,comm="]
        find.standardOutput = read
        try? find.run()
        let output = String(decoding: read.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        find.waitUntilExit()
        guard let line = output.split(separator: "\n").first(where: { $0.hasSuffix("WindowServer") }),
              let time = line.split(separator: " ").first else { return 0 }
        let parts = time.split(separator: ":").compactMap { Double($0) }
        return parts.reduce(0) { $0 * 60 + $1 }
    }

    /// The football and music widgets, their art, and a whole world of them at once.
    static func runFans(services: AppServices) async {
        func widget(_ entry: String, _ size: WidgetSize) -> AnyView {
            let instance = WidgetCatalog.entry(entry)?.make(size: size) ?? WidgetInstance(kind: .clock)
            return AnyView(WidgetBody(instance: instance, services: services).environment(\.widgetIsVisible, true))
        }
        func scene(_ style: ArtStyle, _ palette: ArtPalette) -> AnyView {
            var instance = WidgetInstance(kind: .ambient, size: .large)
            instance.options.art = ArtPiece(style: style, palette: palette)
            return AnyView(WidgetBody(instance: instance, services: services).environment(\.widgetIsVisible, true))
        }
        let seven = ThemeLibrary.set("setup.seven")!
        let world = ZStack(alignment: .topLeading) {
            ForEach(seven.widgets(screenName: nil, bounds: CGSize(width: 1136, height: 768))) { widget in
                WidgetBody(instance: widget, services: services).offset(x: widget.offset.x, y: widget.offset.y)
            }
        }
        .frame(width: 1136, height: 768, alignment: .topLeading)
        .environment(\.widgetIsVisible, true)
        await run(pages: [], views: [
            ("shirt", widget("shirt", .medium)),
            ("player card", widget("playerCard", .large)),
            ("legend card", widget("legendCard", .large)),
            ("tactics board", widget("tacticsBoard", .medium)),
            ("scoreboard", widget("scoreboard", .medium)),
            ("goal counter", widget("goalCounter", .medium)),
            ("cassette", widget("cassette", .medium)),
            ("vhs", widget("vhs", .medium)),
            ("visualizer", widget("visualizer", .medium)),
            ("ring visualizer", widget("ringVisualizer", .large)),
            ("ticket", widget("concertTicket", .medium)),
            ("chrome words", widget("wordArt", .medium)),
            ("glitter words", widget("glitterWord", .medium)),
            ("scene stadium", scene(.stadium, .floodlit)),
            ("scene palms", scene(.palms, .americana)),
            ("scene smoke", scene(.smoke, .slime)),
            ("seven desktop", AnyView(world)),
        ], services: services)
    }

    /// Opens the main window on the Dynamic Island page, closes it, and
    /// reports whether the page is still asking for live system readings.
    static func runWindowClose(services: AppServices) async {
        func cpuSeconds() -> Double {
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6
        }
        func measure(_ label: String) async {
            let start = cpuSeconds()
            try? await Task.sleep(for: .seconds(30))
            print(String(format: "%@: %.2f%% CPU over 30 s", label, (cpuSeconds() - start) / 30 * 100))
        }
        try? await Task.sleep(for: .seconds(5))
        await measure("never opened ")
        services.ui.page = .island
        MainWindowController.shared.show(services: services)
        try? await Task.sleep(for: .seconds(3))
        print("window open:   viewers \(services.monitor.debugViewers)")
        NSApp.windows.first { $0.frameAutosaveName == "AllSetMain" && $0.isVisible }?.performClose(nil)
        try? await Task.sleep(for: .seconds(3))
        print("window closed: viewers \(services.monitor.debugViewers)")
        await measure("after closing")
        // Reopening rebuilds the page, which asks for readings again.
        MainWindowController.shared.show(services: services)
        try? await Task.sleep(for: .seconds(2))
        print("reopened:      viewers \(services.monitor.debugViewers)")
        // The heaviest page: every theme's preview picture.
        print(String(format: "footprint before Themes: %.0f MB", footprintMB()))
        services.ui.page = .themes
        try? await Task.sleep(for: .seconds(12))
        print(String(format: "footprint on Themes:     %.0f MB", footprintMB()))
        print("  caches: \(services.images.debugCacheReport); \(services.themePreviews.debugCacheReport); \(ArtworkCache.debugCacheReport)")
        NSApp.windows.first { $0.frameAutosaveName == "AllSetMain" && $0.isVisible }?.performClose(nil)
        try? await Task.sleep(for: .seconds(5))
        print(String(format: "footprint after closing: %.0f MB", footprintMB()))
        print("  caches: \(services.images.debugCacheReport); \(services.themePreviews.debugCacheReport); \(ArtworkCache.debugCacheReport)")
    }

    /// The process's physical footprint, as Activity Monitor's "Memory" shows it.
    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }

    /// The neon sign for a minute with its flicker on, then off: what the
    /// flicker itself costs (it re-renders glowing text a few times a burst).
    static func runNeon(services: AppServices) async {
        func cpuSeconds() -> Double {
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1e6
        }
        for flicker in [true, false] {
            var instance = WidgetCatalog.entry("neon")?.make(size: .medium) ?? WidgetInstance(kind: .neon)
            instance.options.neonFlicker = flicker
            let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 400, height: 240), styleMask: [.borderless],
                                  backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: WidgetBody(instance: instance, services: services)
                .environment(\.widgetIsVisible, true).frame(width: 400, height: 240))
            window.orderFrontRegardless()
            try? await Task.sleep(for: .seconds(3))
            let start = cpuSeconds()
            try? await Task.sleep(for: .seconds(60))
            print(String(format: "neon flicker %@: %.3f%% CPU over 60 s", flicker ? "on " : "off", (cpuSeconds() - start) / 60 * 100))
            window.close()
        }
    }

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

    private static func measure(_ name: String, seconds: Double) async {
        let start = cpuSeconds()
        let startSystem = systemSeconds()
        let frames = MetalArtView.ArtMetalView.framesDrawn
        try? await Task.sleep(for: .seconds(seconds))
        let drawn = Double(MetalArtView.ArtMetalView.framesDrawn - frames) / seconds
        print(String(format: "%-18@ %5.1f%% CPU (%4.1f%% kernel)  %4.0f GPU frames/s", name as NSString,
                     (cpuSeconds() - start) / seconds * 100, (systemSeconds() - startSystem) / seconds * 100, drawn))
    }

    private static func systemSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
    }

    private static func cpuSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        func seconds(_ time: timeval) -> Double { Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000 }
        return seconds(usage.ru_utime) + seconds(usage.ru_stime)
    }
}
#endif

#if DEBUG
@Observable @MainActor
final class ProbeOcclusion {
    var isOccluded = false
}

private struct ProbeOccludedWidget: View {
    let instance: WidgetInstance
    let services: AppServices
    let state: ProbeOcclusion

    var body: some View {
        WidgetBody(instance: instance, services: services)
            .environment(\.widgetIsVisible, !state.isOccluded)
            .environment(\.widgetIsOnScreen, !state.isOccluded)
    }
}
#endif
