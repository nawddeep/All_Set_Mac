import AllSetCore
import AppKit
import SwiftUI

#if DEBUG

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
        let seven = ThemeLibrary.set("setup.floodlightGold")!
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
        for id in ["setup.floodlightGold", "setup.americana", "setup.wonderkid"] {
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
        for id in ["setup.floodlightGold", "setup.wonderkid", "setup.americana", "setup.floodlightGold"] {
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
    static func windowServerSeconds() -> Double {
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
        let seven = ThemeLibrary.set("setup.floodlightGold")!
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

    static func measure(_ name: String, seconds: Double) async {
        let start = cpuSeconds()
        let startSystem = systemSeconds()
        let frames = MetalArtView.ArtMetalView.framesDrawn
        try? await Task.sleep(for: .seconds(seconds))
        let drawn = Double(MetalArtView.ArtMetalView.framesDrawn - frames) / seconds
        print(String(format: "%-18@ %5.1f%% CPU (%4.1f%% kernel)  %4.0f GPU frames/s", name as NSString,
                     (cpuSeconds() - start) / seconds * 100, (systemSeconds() - startSystem) / seconds * 100, drawn))
    }

    static func systemSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
    }

    static func cpuSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        func seconds(_ time: timeval) -> Double { Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000 }
        return seconds(usage.ru_utime) + seconds(usage.ru_stime)
    }
}
#endif
