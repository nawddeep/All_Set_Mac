import AllSetCore
import AppKit
import Observation
import SwiftUI

#if DEBUG

extension WidgetRenderHarness {
    /// Every design theme in light and dark, on real widgets, captured from
    /// real windows (behind the desktop picture, so nothing shows on screen),
    /// so glass and system materials draw as they do on the desktop.
    static func renderDesignThemes(to folder: URL, services: AppServices) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? ArtGPU.compileNow()
        let pune = WeatherLocation(name: "Pune", latitude: 18.52, longitude: 73.86)
        services.weather.refreshIfNeeded(pune)
        services.monitor.start()
        services.monitor.setViewer("harness", visible: true, interval: 1)
        try? await Task.sleep(for: .seconds(3))
        let entries: [(String, WidgetSize)] = [("minimalClock", .small), ("date", .small), ("cpu", .medium),
                                               ("weather", .medium), ("goals", .medium)]
        for theme in DesignTheme.all {
            for dark in [false, true] where dark ? theme.dark != nil : theme.light != nil {
                let widgets = entries.compactMap { id, size -> WidgetInstance? in
                    guard var widget = WidgetCatalog.entry(id)?.make(size: size) else { return nil }
                    widget.options.designTheme = theme.id
                    widget.options.appearance = dark ? .dark : .light
                    widget.options.location = pune
                    return widget
                }
                let view = VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) { ForEach(widgets.prefix(3)) { WidgetBody(instance: $0, services: services) } }
                    HStack(spacing: 16) { ForEach(widgets.dropFirst(3)) { WidgetBody(instance: $0, services: services) } }
                }
                .padding(24)
                .background {
                    if let wallpaper = theme.wallpaper, case .art(let piece) = wallpaper {
                        ArtView(piece: piece)
                    } else {
                        StudioBackdrop(piece: ArtPiece(style: .blobs, palette: dark ? .midnight : .pastel))
                    }
                }
                .environment(\.widgetIsPreview, true)
                .environment(\.widgetIsVisible, false)
                .environment(\.colorScheme, dark ? .dark : .light)
                if let image = await capture(view, size: CGSize(width: 768, height: 400)),
                   let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                    try? png.write(to: folder.appendingPathComponent("design-\(theme.id)-\(dark ? "dark" : "light").png"))
                }
            }
        }
        await renderEntries(to: folder, services: services, categories: [.productivity, .system, .developer, .lifestyle, .aesthetic, .time])
        services.monitor.setViewer("harness", visible: false)
    }

    /// Every catalog entry in `categories`, at each size it offers, in its own
    /// starting look: captured live from a hidden window, and drawn as the
    /// still snapshot the Themes page uses.
    static func renderEntries(to folder: URL, services: AppServices, categories: [WidgetCategory]) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let pune = WeatherLocation(name: "Pune", latitude: 18.52, longitude: 73.86)
        // `-entryIDs a,b` narrows it to those entries.
        let ids = UserDefaults.standard.string(forKey: "entryIDs").map { Set($0.split(separator: ",").map(String.init)) }
        for entry in WidgetCatalog.entries where categories.contains(entry.category) && ids.map({ $0.contains(entry.id) }) ?? true {
            for image in entry.make().options.images { _ = await services.images.image(for: image) }
            for size in entry.sizes {
                var widget = entry.make(size: size)
                widget.options.location = pune
                if widget.kind == .github { widget.options.github.user = "torvalds"; widget.options.github.repository = "torvalds/linux" }
                let dimensions = size.dimensions
                let view = WidgetBody(instance: widget, services: services)
                    .padding(20)
                    .background(StudioBackdrop(piece: ArtPiece(style: .blobs, palette: .midnight)))
                    .environment(\.widgetIsPreview, true)
                if let image = await capture(view, size: CGSize(width: dimensions.width + 40, height: dimensions.height + 40)),
                   let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                    try? png.write(to: folder.appendingPathComponent("entry-\(entry.id)-\(size.rawValue).png"))
                }
                let still = ImageRenderer(content: view.environment(\.widgetSnapshot, true)
                    .frame(width: dimensions.width + 40, height: dimensions.height + 40))
                still.scale = 2
                if let image = still.cgImage, let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                    try? png.write(to: folder.appendingPathComponent("snap-\(entry.id)-\(size.rawValue).png"))
                }
            }
        }
    }

    /// Every theme set's card preview through the app's own preview cache,
    /// then the Themes page and a detail page captured from hidden windows.
    static func renderThemeSets(to folder: URL, services: AppServices) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? ArtGPU.compileNow()
        services.monitor.start()
        let cache = services.themePreviews
        let collection = UserDefaults.standard.string(forKey: "themeCollection").flatMap(ThemeCollection.init(rawValue:))
        let requestedIDs = Set((UserDefaults.standard.string(forKey: "themeIDs") ?? "")
            .split(separator: ",").map { "setup.\($0)" })
        let collectionSets = collection.map { ThemeLibrary.sets(in: $0) } ?? ThemeLibrary.all
        let sets = requestedIDs.isEmpty ? collectionSets : collectionSets.filter { requestedIDs.contains($0.id) }
        if collection == .funkyThemes || collection == .datasetTwo || collection == .desktopEdit || collection == .studioOriginals {
            let ids = sets.map(\.id)
            // Warm both stores before comparing lookup work.
            _ = ThemeWidgetCatalog.all.count
            _ = ThemeWidgetCatalog.widgets(in: ids[0]).count
            var scanned = 0, indexed = 0
            let scanStart = CACurrentMediaTime()
            for _ in 0..<500 {
                for id in ids { scanned += ThemeWidgetCatalog.all.filter { $0.setID == id }.count }
            }
            let scanTime = CACurrentMediaTime() - scanStart
            let indexStart = CACurrentMediaTime()
            for _ in 0..<500 {
                for id in ids { indexed += ThemeWidgetCatalog.widgets(in: id).count }
            }
            print(String(format: "LOOKUP 12500 calls: scan %.2f ms, indexed %.2f ms; matched %d / %d widgets", scanTime * 1000,
                         (CACurrentMediaTime() - indexStart) * 1000, scanned, indexed))
        }
        for set in sets {
            let appearances = set.designTheme?.followsAppearance == true ? [false, true] : [set.isDark]
            for dark in appearances {
                for variant in [ThemePreviewVariant.desktop, .card] {
                    cache.request(set, dark: dark, variant: variant, services: services)
                    for _ in 0..<300 where cache.image(for: set, dark: dark, variant: variant) == nil { try? await Task.sleep(for: .milliseconds(100)) }
                    if let image = cache.image(for: set, dark: dark, variant: variant), let tiff = image.tiffRepresentation,
                       let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                        try? png.write(to: folder.appendingPathComponent("\(variant == .card ? "card" : "set")-\(set.id)-\(dark ? "dark" : "light").png"))
                    } else { print("MISSING preview \(set.id) \(variant)") }
                }
            }
        if collection == .funkyThemes || collection == .datasetTwo || collection == .desktopEdit || collection == .studioOriginals {
                let widgets = ThemeWidgetCatalog.widgets(in: set.id)
                let view = VStack(alignment: .leading, spacing: 12) {
                    Text("\(set.name) · \(widgets.count) widgets").font(.title2).foregroundStyle(.white)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(270)), count: 4), spacing: 12) {
                        ForEach(widgets) { ThemeWidgetCard(widget: $0, services: services, showThemeName: true).frame(width: 270, height: 220) }
                    }
                    Spacer(minLength: 0)
                }.padding(20).background(Color(white: 0.06)).preferredColorScheme(.dark)
                if let image = await capture(view, size: CGSize(width: 1160, height: 780)),
                   let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                    try? png.write(to: folder.appendingPathComponent("widgets-\(set.id).png"))
                }
            }
            print("RENDERED \(set.id) · \(ThemeWidgetCatalog.widgets(in: set.id).count) widgets")
            if collection == .funkyThemes {
                await renderSuppliedDesktops(set, to: folder, services: services)
            }
        }
        for (name, view) in [("page-themes", AnyView(ThemesPage(services: services))),
                             ("page-detail", AnyView(ThemeDetailPage(setID: sets.first?.id ?? "setup.floodlightGold", services: services))),
                             ("page-widgets", AnyView(CinematicCatalog(services: services, width: 1060, filter: .all, category: nil, query: "", themesOnly: true, favoriteIDs: nil)))] {
            if let image = await capture(view.background(Color(nsColor: .windowBackgroundColor)).preferredColorScheme(.dark), size: CGSize(width: 1100, height: 900)),
               let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try? png.write(to: folder.appendingPathComponent("\(name).png"))
            }
        }
    }

    /// The island in a real (hidden) window, in each state and mid-spring.
    static func renderIsland(to folder: URL, services: AppServices) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        services.monitor.setViewer("harness", visible: true)
        let model = NotchViewModel(geometry: NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 940, height: 340),
                                                           safeAreaTop: 32, topLeftArea: nil, topRightArea: nil, menuBarHeight: 32))
        let size = NotchViewModel.windowSize
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: 80, y: 80), size: size), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(white: 0.55, alpha: 1)
        window.contentView = IslandView(model: model, root: NotchRootView(model: model, services: services, expand: {}, openSettings: {}))
        window.orderFrontRegardless()
        func shot(_ name: String, after milliseconds: Int) async {
            try? await Task.sleep(for: .milliseconds(milliseconds))
            if let image = captureOwnWindow(window), let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try? png.write(to: folder.appendingPathComponent("island-\(name).png"))
            }
        }
        await shot("1-closed", after: 1500)
        withAnimation(NotchAnimation.activity) { model.transientActivity = .volume(level: 0.6, muted: false) }
        await shot("2-volume", after: 900)
        withAnimation(NotchAnimation.activity) { model.transientActivity = nil }
        try? await Task.sleep(for: .milliseconds(600))
        withAnimation(NotchAnimation.open) { model.isExpanded = true }
        await shot("3-opening", after: 90)
        await shot("4-home", after: 1500)
        withAnimation(NotchAnimation.tab) { model.tab = .system }
        await shot("5-to-system", after: 110)
        await shot("6-system", after: 1500)
        withAnimation(NotchAnimation.close) { model.isExpanded = false }
        await shot("7-closing", after: 110)
        await shot("8-closed", after: 1200)
        window.close()
    }

    /// The same widgets at 130%, scaled by SwiftUI and by AppKit bounds, for
    /// comparing how sharp each stays.
    static func renderScaling(to folder: URL, services: AppServices) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let widgets = ["shirt", "visualizer", "vinyl"].compactMap { WidgetCatalog.entry($0)?.make(size: .medium) }
        let base = CGSize(width: 352, height: 168 * 3 + 32)
        let scale = 1.3
        let column = VStack(spacing: 16) { ForEach(widgets) { WidgetBody(instance: $0, services: services) } }
            .frame(width: base.width, height: base.height).background(Color.gray)
            .environment(\.widgetIsPreview, true)
        for (name, view, size) in [("native", AnyView(column), base),
                                   ("swiftui", AnyView(column.scaleEffect(scale, anchor: .topLeading)
                                        .frame(width: base.width * scale, height: base.height * scale, alignment: .topLeading)),
                                    CGSize(width: base.width * scale, height: base.height * scale))] {
            if let image = await capture(view, size: size), let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try? png.write(to: folder.appendingPathComponent("scale-\(name).png"))
            }
        }
        // AppKit: the view lays out at its own size; its bounds are scaled into a bigger frame.
        let host = NSHostingView(rootView: column)
        host.sizingOptions = []
        let size = CGSize(width: base.width * scale, height: base.height * scale)
        host.frame = CGRect(origin: .zero, size: size)
        host.setBoundsSize(base)
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: 80, y: 80), size: size), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        try? await Task.sleep(for: .milliseconds(900))
        if let image = captureOwnWindow(window), let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            try? png.write(to: folder.appendingPathComponent("scale-appkit.png"))
        }
        window.close()
    }

    /// `-probe resize` (with `-widgetsFile` pointing at a throwaway layout):
    /// drags a real widget window's corner through several sizes, saving the
    /// window after each step and printing what the store ends up with.
    static func runResize(controller: DesktopWidgetController, services: AppServices, to folder: URL) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? await Task.sleep(for: .seconds(1.5))
        guard let target = services.widgets.widgets.first(where: { $0.size == .medium }) ?? services.widgets.widgets.first,
              let window = controller.debugWindow(target.id) else { print("resize: no widget"); return }
        func save(_ name: String) async {
            try? await Task.sleep(for: .milliseconds(450))
            if let image = captureOwnWindow(window), let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try? png.write(to: folder.appendingPathComponent("resize-\(name).png"))
            }
        }
        func report(_ step: String, ms: Double) {
            let live = window.state.liveSize.map { "\($0.shortTitle) × \(String(format: "%.2f", window.state.liveScale ?? 1))" } ?? "-"
            print(String(format: "resize %-14@ live %-10@ window %4.0f × %4.0f  (%.1f ms)", step, live,
                         window.frame.width, window.frame.height, ms))
        }
        let margin = WidgetWindow.margin * window.state.contentScale
        // The real pointer, onto the corner, through the real monitor.
        let corner = CGPoint(x: window.frame.maxX - margin - 6, y: window.frame.minY + margin + 6)
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        CGWarpMouseCursorPosition(CGPoint(x: corner.x, y: screenHeight - corner.y))
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: corner.x, y: screenHeight - corner.y), mouseButton: .left)?.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(600))
        print("resize hover: pointer", NSEvent.mouseLocation, "corner", corner, "windowFrame", window.frame, "topWindow", NSWindow.windowNumber(at: corner, belowWindowWithWindowNumber: 0), "this", window.windowNumber, "cornerHovered", window.state.cornerHovered)
        await save("0-hover")
        let start = CGPoint(x: window.frame.maxX - margin, y: window.frame.minY + margin)
        let steps: [(String, CGFloat, CGFloat)] = [
            ("1-bigger", 90, -45), ("2-square", 0, -184), ("3-small", -184, 0),
            ("4-smallest", -260, 80), ("5-final", 60, -120),
        ]
        for (name, dx, dy) in steps {
            let began = CACurrentMediaTime()
            controller.debugResize(target.id, .changed, pointer: CGPoint(x: start.x + dx, y: start.y + dy))
            report(name, ms: (CACurrentMediaTime() - began) * 1000)
            await save(name)
        }
        controller.debugResize(target.id, .ended, pointer: CGPoint(x: start.x + 60, y: start.y - 120))
        window.state.cornerHovered = false
        await save("6-released")
        guard let saved = services.widgets.instance(target.id) else { return }
        print(String(format: "resize saved: %@ × %.3f at (%.0f, %.0f), window %.0f × %.0f", saved.size.title, saved.scale,
                     saved.offset.x, saved.offset.y, window.frame.width, window.frame.height))
        let rects = services.widgets.widgets.map { CGRect(origin: $0.offset, size: $0.footprint) }
        var overlaps = 0
        for (index, rect) in rects.enumerated() {
            for other in rects[(index + 1)...] where rect.intersects(other.insetBy(dx: 1, dy: 1)) { overlaps += 1 }
        }
        for widget in services.widgets.widgets {
            print(String(format: "resize   %@ %@ × %.2f at (%.0f, %.0f)", widget.kind.rawValue, widget.size.shortTitle,
                         widget.scale, widget.offset.x, widget.offset.y))
        }
        print("resize overlaps:", overlaps)
    }

    static func capture(_ view: some View, size: CGSize) async -> CGImage? {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: 80, y: 80), size: size), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        try? await Task.sleep(for: .milliseconds(900))
        let image = captureOwnWindow(window)
        window.close()
        return image
    }
}

extension WidgetRenderHarness {
    /// `-renderWallpaperLibrary folder`: My Videos with the imported library,
    /// at the top and scrolled down to the library grid.
    static func renderWallpaperLibrary(to folder: URL, services: AppServices) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 1100, height: 900), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = NSHostingView(rootView: ClassicWallpaperPage(services: services).frame(width: 1100, height: 900))
        window.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(4))
        for (index, offset) in [0.0, 700, 1400].enumerated() {
            if let scroll = Self.firstScrollView(in: window.contentView) {
                scroll.contentView.scroll(to: NSPoint(x: 0, y: offset))
                scroll.reflectScrolledClipView(scroll.contentView)
            }
            try? await Task.sleep(for: .seconds(3))
            if let image = captureOwnWindow(window), let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try? png.write(to: folder.appendingPathComponent("library-\(index + 1).png"))
            }
        }
        window.close()
    }

    static func firstScrollView(in view: NSView?) -> NSScrollView? {
        guard let view else { return nil }
        if let scroll = view as? NSScrollView, scroll.documentView != nil, scroll.frame.height > 300 { return scroll }
        for child in view.subviews {
            if let found = firstScrollView(in: child) { return found }
        }
        return nil
    }

    /// `-renderPhotos folder`: the Photos page after a few real searches, as the window shows it.
    static func renderPhotos(to folder: URL, services: AppServices) async {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (index, text) in ["iron man", "coquette", "lambo"].enumerated() {
            services.search.search(text, immediately: true)
            let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 1100, height: 900), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView = NSHostingView(rootView: WebPhotosPage(services: services).frame(width: 1100, height: 900))
            window.orderFrontRegardless()
            try? await Task.sleep(for: .seconds(7))
            if let image = captureOwnWindow(window), let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try? png.write(to: folder.appendingPathComponent("photos-\(index + 1).png"))
            }
            window.close()
        }
    }
}

extension WidgetRenderHarness {
    /// Every page of the main window, by the name `-renderPages` files it under.
    static let pages: [(name: String, page: AppPage)] = [
        ("island", .island), ("activities", .activities), ("favorites", .favorites), ("themes", .themes), ("theme-seven", .themeSet("setup.floodlightGold")),
        ("gallery", .gallery(nil)), ("gallery-themes", .gallery(nil)), ("look", .widgetAppearance), ("desktop", .desktop), ("widget", .desktop), ("wallpaper", .wallpaper),
        ("wallpaper-options", .wallpaperOptions), ("snapping", .snapping), ("workspaces", .workspaces),
        ("clipboard", .clipboard), ("shelf", .shelf), ("mixer", .mixer), ("taptap", .knocks), ("notes", .notes),
        ("screenshot", .screenshot), ("extras", .extras), ("monitor", .monitor), ("general", .general), ("about", .about),
    ]

    /// Opt-in visual cases; keep the normal CI page/probe inventory unchanged.
    private static let spotlightPages: [(name: String, page: AppPage)] = [
        ("gallery-focus", .gallery(nil)), ("gallery-analog", .gallery(nil)), ("gallery-weather", .gallery(nil)),
        ("gallery-calendar", .gallery(nil)), ("gallery-system", .gallery(nil)), ("gallery-music", .gallery(nil)),
    ]

    /// `-renderPages folder [-pages wallpaper,themes] [-pageSizes 900x600,1280x800]`:
    /// the real main window, navigation and all, on each page at each size, as
    /// PNGs named `<page>-<width>x<height>.png`. For checking the UI without
    /// sitting at the Mac (CI uploads them). `-reduceMotion 1` and
    /// `-lowPower 1` show the pages as they are with Reduce Motion on or in
    /// Low Power Mode, whatever this Mac is set to. `-pageScroll 90` saves
    /// each page a second time, scrolled that far (`…-scrolled.png`), to see
    /// what passes under the navigation.
    /// Returns the pictures it meant to save but couldn't (empty when all were
    /// saved), and lists them in `render-report.txt`, so CI can fail on a partial set.
    @discardableResult
    static func renderPages(to folder: URL, services: AppServices) async -> [String] {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var expected: [String] = []
        var missing: [String] = []
        func save(_ image: CGImage?, as name: String) {
            expected.append(name)
            guard let image, let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]),
                  (try? png.write(to: folder.appendingPathComponent(name))) != nil else {
                missing.append(name)
                return
            }
        }
        if UserDefaults.standard.bool(forKey: "reduceMotion") { services.ui.performance.reducesMotion = true }
        if UserDefaults.standard.bool(forKey: "lowPower") { services.ui.performance.isLowPower = true }
        let scrolled = UserDefaults.standard.double(forKey: "pageScroll")
        let wanted = UserDefaults.standard.string(forKey: "pages").map { Set($0.split(separator: ",").map(String.init)) }
        let sizes = (UserDefaults.standard.string(forKey: "pageSizes") ?? "900x600,1280x800,1728x1080")
            .split(separator: ",")
            .compactMap { pair -> CGSize? in
                let parts = pair.split(separator: "x").compactMap { Double($0) }
                return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil
            }
        try? ArtGPU.compileNow()
        // A fresh machine has no widgets; borrow two so On Your Desktop and
        // the customizer have something to show, and put things back after.
        var borrowed: [UUID] = []
        if services.widgets.widgets.isEmpty {
            for kind in [WidgetKind.clock, .weather] {
                if let entry = WidgetCatalog.entries.first(where: { $0.kind == kind }) {
                    borrowed.append(services.addWidget(entry.make()).id)
                }
            }
        }
        defer { for id in borrowed { services.widgets.remove(id) } }
        // Draw the Themes page's first previews up front, timing each: a CI
        // machine is slow at this, and the times show where it goes.
        let cache = services.themePreviews
        for set in ThemeDiscovery.featured.sets(stats: services.themeStats).prefix(4) {
            let started = Date.now
            cache.request(set, dark: set.isDark, services: services)
            for _ in 0..<300 where cache.image(for: set, dark: set.isDark) == nil { try? await Task.sleep(for: .milliseconds(100)) }
            let seconds = Date.now.timeIntervalSince(started)
            print("theme preview \(set.id): \(cache.image(for: set, dark: set.isDark) == nil ? "not drawn after" : "drawn in") \(String(format: "%.1f", seconds)) s")
            cache.cancel(set, dark: set.isDark)
        }
        let window = UnconstrainedWindow(contentRect: CGRect(origin: CGPoint(x: 80, y: 80), size: sizes.first ?? CGSize(width: 1280, height: 800)),
                                         styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                         backing: .buffered, defer: false)
        MainWindowController.dress(window)
        window.isReleasedWhenClosed = false
        // Behind the desktop picture: captured, never seen.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
        window.ignoresMouseEvents = true
        let controller = MainWindowController.contentController(services: services)
        window.contentViewController = controller
        window.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(2))
        for size in sizes {
            window.setContentSize(size)
            for (name, page) in pages + spotlightPages.filter({ wanted?.contains($0.name) == true }) where wanted?.contains(name) ?? true {
                services.ui.galleryFromThemes = name == "gallery-themes"
                if case .gallery = page {
                    // Fresh page state lets visual checks cover square, wide
                    // and tall spotlight widgets, rather than just the clock.
                    services.ui.page = .about
                    // Wait for the 300 ms page transition to actually unmount
                    // the previous gallery and release its @State.
                    try? await Task.sleep(for: .milliseconds(700))
                    services.ui.studioWidgetSelection = ["gallery-focus": "focusTimer", "gallery-analog": "analogClock",
                        "gallery-weather": "weather", "gallery-calendar": "calendar", "gallery-system": "systemMonitor",
                        "gallery-music": "music"][name] ?? "digitalClock"
                }
                // "widget" is the first desktop widget's settings, whichever that is.
                services.ui.page = name == "widget" ? services.widgets.widgets.first.map { .widget($0.id) } ?? page : page
                // Long enough for thumbnails, previews and first samples to
                // land; pages of rendered previews need longer the first time.
                // Theme previews are drawn one at a time, photos and cut-outs
                // first, which takes a CI machine a while.
                let settle = name == "themes" ? 8000
                    : ["theme-seven", "gallery", "gallery-themes", "wallpaper"].contains(name) ? 6000 : 1800
                try? await Task.sleep(for: .milliseconds(settle))
                save(captureOwnWindow(window), as: "\(name)-\(Int(size.width))x\(Int(size.height)).png")
                if scrolled > 0, let scroll = PageCPUProbe.tallestScrollView(in: window.contentView) {
                    let clip = scroll.contentView, top = clip.bounds.origin
                    clip.scroll(to: NSPoint(x: top.x, y: top.y + scrolled))
                    scroll.reflectScrolledClipView(clip)
                    try? await Task.sleep(for: .milliseconds(600))
                    save(captureOwnWindow(window), as: "\(name)-\(Int(size.width))x\(Int(size.height))-scrolled.png")
                    clip.scroll(to: top)
                    scroll.reflectScrolledClipView(clip)
                }
            }
        }
        window.close()
        let report = "expected \(expected.count), saved \(expected.count - missing.count)\n" + missing.map { "missing \($0)\n" }.joined()
        try? report.write(to: folder.appendingPathComponent("render-report.txt"), atomically: true, encoding: .utf8)
        print(report, terminator: "")
        return missing
    }
}
#endif
