import AllSetCore
import AppKit
import CoreImage
import Observation
import OSLog
import SwiftUI

/// A theme set's widgets laid out on its wallpaper, as they'd sit on the
/// desktop. Drawn live for a theme's hero, and into pictures for cards.
struct ThemeComposition: View {
    let set: ThemeSet
    let widgets: [WidgetInstance]
    let services: AppServices
    var dark = true
    /// Lets the wallpaper move (the live hero, while hovered).
    var isLive = false

    /// The area the layouts are designed in: six small cells by four.
    static let canvas = CGSize(width: 1136, height: 768)

    var body: some View {
        GeometryReader { geometry in
            let scale = max(geometry.size.width / Self.canvas.width, geometry.size.height / Self.canvas.height)
            ZStack(alignment: .topLeading) {
                ThemeWallpaper(set: set, services: services, dark: dark, isLive: isLive)
                ZStack(alignment: .topLeading) {
                    ForEach(widgets) { widget in
                        WidgetBody(instance: widget, services: services)
                            .modifier(CompositionShadow(hasCard: widget.hasCard))
                            .offset(x: widget.offset.x, y: widget.offset.y)
                    }
                }
                .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading)
                .environment(\.widgetIsVisible, false)
                .environment(\.widgetIsPreview, true)
                .environment(\.colorScheme, dark ? .dark : .light)
                .scaleEffect(scale, anchor: .topLeading)
                .allowsHitTesting(false)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
        }
    }

    /// The set's widgets, in the given appearance, with a city for anything
    /// that needs one, ready to preview.
    @MainActor
    static func widgets(for set: ThemeSet, dark: Bool, services: AppServices) -> [WidgetInstance] {
        let city = services.widgets.widgets.lazy.compactMap(\.options.location).first ?? Self.city
        let widgets = ThemeSet.personalized(set.widgets(screenName: nil, bounds: canvas), with: services.themePhotos.sources(for: set.id))
        return widgets.map { widget in
            var widget = widget
            if set.designTheme?.followsAppearance == true { widget.options.appearance = dark ? .dark : .light }
            if [.weather, .airQuality, .daylight].contains(widget.kind), widget.options.location == nil { widget.options.location = city }
            return widget
        }
    }

    @MainActor private static let city = TimeZonePlace.guess()
}

private struct CompositionShadow: ViewModifier {
    let hasCard: Bool

    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(hasCard ? 0.2 : 0), radius: 7, y: 3)
    }
}

/// A theme set's wallpaper, filling whatever frame it's given: a landscape
/// desktop or a portrait card alike.
struct ThemeWallpaper: View {
    let set: ThemeSet
    let services: AppServices
    var dark = true
    /// Lets it move.
    var isLive = false

    var body: some View {
        Group {
            switch set.wallpaper {
            case .art(let piece):
                ArtView(piece: piece, animated: isLive)
            case .photo(let source):
                PhotoContent(source: source, filter: .none, tint: .white, animated: false, library: services.images, maxPixels: 1200)
            case .video, .library, nil:
                StudioBackdrop(piece: ArtPiece(style: .blobs, palette: dark ? .midnight : .pastel))
            }
        }
        .environment(\.widgetIsVisible, isLive)
    }
}

/// A theme set's card for the Themes carousel: its wallpaper edge to edge
/// and a few of its widgets floating over the upper part (`ThemeCardArt`).
/// Drawn into a picture, never live.
struct ThemeCardComposition: View {
    let set: ThemeSet
    /// All of the set's widgets, in layout order.
    let widgets: [WidgetInstance]
    let services: AppServices
    var dark = true

    var body: some View {
        let picks = ThemeCardArt.curated[set.id] ?? ThemeCardArt.picks(from: widgets.map { ($0.kind, $0.size) })
        let pieces = picks.map { ThemeCardArt.pieces($0, sizes: widgets.map(\.size)) } ?? []
        let zoom = picks?.zoom ?? 1, focus = picks?.focus ?? CGPoint(x: 0.5, y: 0.5)
        GeometryReader { geometry in
            let scale = max(geometry.size.width / ThemeCardArt.canvas.width, geometry.size.height / ThemeCardArt.canvas.height)
            ZStack(alignment: .topLeading) {
                // The card's own size, so all of the wallpaper shows; or
                // larger and shifted, to crop it around its focus.
                ThemeWallpaper(set: set, services: services, dark: dark)
                    .frame(width: geometry.size.width * zoom, height: geometry.size.height * zoom)
                    .offset(x: -geometry.size.width * (zoom - 1) * focus.x, y: -geometry.size.height * (zoom - 1) * focus.y)
                ZStack(alignment: .topLeading) {
                    ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                        let widget = widgets[piece.widget]
                        WidgetBody(instance: widget, services: services)
                            // Floating: a deeper shadow than on the desktop.
                            .shadow(color: .black.opacity(widget.hasCard || widget.kind.paintsOwnBackground ? 0.4 : 0), radius: 16, y: 10)
                            .scaleEffect(piece.scale, anchor: .topLeading)
                            .offset(x: piece.origin.x, y: piece.origin.y)
                    }
                }
                .frame(width: ThemeCardArt.canvas.width, height: ThemeCardArt.canvas.height, alignment: .topLeading)
                .environment(\.widgetIsVisible, false)
                .environment(\.widgetIsPreview, true)
                .environment(\.colorScheme, dark ? .dark : .light)
                .scaleEffect(scale, anchor: .topLeading)
                // Scaling doesn't shrink what it takes up: without this the
                // canvas's full size would stretch the wallpaper beside it.
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .allowsHitTesting(false)

                // Baked card sheen
                LinearGradient(colors: [.white.opacity(0.12), .clear, .black.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .blendMode(.overlay)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
        }
    }
}

/// The pictures the cache keeps of a theme set.
enum ThemePreviewVariant {
    /// The whole desktop, as the rails and the theme's own page show it.
    case desktop
    /// The portrait card for the Themes carousel.
    case card
    /// The wallpaper alone, small, blurred until only its light is left and
    /// fading out toward the bottom: the Themes page's atmosphere lays it
    /// over the page as it is.
    case backdrop

    /// Width over height.
    @MainActor var aspect: CGFloat {
        switch self {
        case .desktop: ThemeComposition.canvas.width / ThemeComposition.canvas.height
        case .card: ThemeCardArt.canvas.width / ThemeCardArt.canvas.height
        case .backdrop: Self.backdropSize.width / Self.backdropSize.height
        }
    }

    /// Small: it's only ever seen blurred and stretched.
    static let backdropSize = CGSize(width: 384, height: 240)

    /// What marks its files. Desktops have none; the others end in a number
    /// to bump when the way they're drawn (or, for cards, which widgets
    /// they show) changes, to redraw them.
    fileprivate var mark: String {
        switch self {
        case .desktop: ""
        case .card: "-card"
        case .backdrop: "-backdrop"
        }
    }

    fileprivate var suffix: String {
        switch self {
        case .desktop: ""
        case .card: "-card7"
        case .backdrop: "-backdrop2"
        }
    }

    /// Whether a file in the cache is one of this kind's.
    fileprivate func owns(_ file: String) -> Bool {
        switch self {
        case .desktop: !file.contains(ThemePreviewVariant.card.mark) && !file.contains(ThemePreviewVariant.backdrop.mark)
        case .card, .backdrop: file.contains(mark)
        }
    }
}

/// Pictures of theme sets for the library's cards: drawn once each, when a
/// card first needs one, then kept in memory and on disk. Only visible cards
/// ask, so scrolling the library never draws dozens of live widgets.
@Observable @MainActor
final class ThemePreviewCache {
    /// Each card observes its own image. Publishing one preview must not
    /// re-layout every other card in the library.
    @Observable fileprivate final class Preview {
        var image: NSImage?
    }
    @ObservationIgnored private var previews: [String: Preview] = [:]

    private func preview(_ name: String) -> Preview {
        if let existing = previews[name] { return existing }
        let entry = Preview()
        previews[name] = entry
        return entry
    }
    /// The color of each set's wallpaper, by set id, measured from its
    /// backdrop picture once there is one: what a theme with no accent of
    /// its own is lit with (`ThemeSet.lighting`). Missing for a wallpaper
    /// with no color to speak of.
    private(set) var wallpaperColors: [String: WidgetColor] = [:]

    @ObservationIgnored private let photos: ThemePhotos

    #if DEBUG
    var debugCacheReport: String {
        String(format: "previews %d (%.0f MB)", previews.values.filter { $0.image != nil }.count, Double(bytes) / 1_048_576)
    }
    #endif

    init(photos: ThemePhotos) {
        self.photos = photos
        // Drawing a preview holds the main thread for a moment (a long one
        // for a busy desktop); during a scroll that's a stall you can feel.
        // So drawing waits while any scroll view is being scrolled.
        let center = NotificationCenter.default
        scrollObservers = [
            center.addObserver(forName: NSScrollView.willStartLiveScrollNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scrollsUnderWay += 1 }
            },
            center.addObserver(forName: NSScrollView.didEndLiveScrollNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.scrollsUnderWay = max(self.scrollsUnderWay - 1, 0)
                    self.lastScrollEnd = CACurrentMediaTime()
                }
            },
        ]
        // Pictures from older ways of drawing (or naming) previews never match again.
        let folder = folder, current = "-d\(Self.drawingVersion)-"
        Task.detached(priority: .background) {
            for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] where !name.contains(current) {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
            }
        }
    }

    @ObservationIgnored private var inFlight = Set<String>()
    @ObservationIgnored private let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("AllSet/ThemePreviews", isDirectory: true)
    @ObservationIgnored private let log = Logger(subsystem: "com.pratik.allset", category: "themes")

    /// Bump when the way previews are drawn changes, to redraw them all.
    private static let drawingVersion = 5

    /// The app's version: a release redraws previews; rebuilding the same one doesn't.
    private static let appVersion: String = {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "0")-\(info?["CFBundleVersion"] as? String ?? "0")"
    }()

    /// What each set shows, boiled down to a number: its widgets and their
    /// settings (on a fixed date, so countdowns don't change it) and its wallpaper.
    @ObservationIgnored private var fingerprints: [String: String] = [:]

    private func fingerprint(_ set: ThemeSet) -> String {
        if let known = fingerprints[set.id] { return known }
        let widgets = set.widgets(screenName: nil, bounds: ThemeComposition.canvas, now: Date(timeIntervalSince1970: 0))
            .map { widget in
                var widget = widget
                widget.id = UUID(uuid: UUID_NULL)
                // Countdowns are set relative to today; the preview needn't follow.
                widget.options.match.kickoff = nil
                widget.options.ticket.date = nil
                widget.options.countdownDate = nil
                return widget
            }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in (try? encoder.encode(widgets)) ?? Data() { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
        for byte in "\(String(describing: set.wallpaper))".utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
        let print = String(hash, radix: 36)
        fingerprints[set.id] = print
        return print
    }

    /// Changes when what the preview shows does: the set's contents, the
    /// person's photos for it, the app's version or the way previews are drawn.
    func key(_ set: ThemeSet, dark: Bool, variant: ThemePreviewVariant = .desktop) -> String {
        "\(set.id)-\(dark ? "dark" : "light")-\(fingerprint(set))-\(Self.appVersion)-d\(Self.drawingVersion)-p\(photos.version(of: set.id))\(variant.suffix)"
    }

    func image(for set: ThemeSet, dark: Bool, variant: ThemePreviewVariant = .desktop) -> NSImage? {
        let name = key(set, dark: dark, variant: variant)
        guard let image = preview(name).image else { return nil }
        useCount += 1
        lastUse[name] = useCount
        return image
    }

    /// Previews kept in memory beyond the cards on screen, which always keep
    /// theirs. The rest come back from disk (a few milliseconds each, off the
    /// main thread) when scrolled to again.
    private static let memoryLimit = 48 << 20
    /// Cards on screen, by preview: never evicted from under them.
    @ObservationIgnored private var showing: [String: Int] = [:]
    @ObservationIgnored private var lastUse: [String: Int] = [:]
    @ObservationIgnored private var useCount = 0
    @ObservationIgnored private var bytes = 0
    /// Goes up with every purge. Observed: cards on screen ask again when it
    /// changes, since a purge drops the requests they were waiting on.
    private(set) var generation = 0

    private func keep(_ image: CGImage, as name: String, of set: ThemeSet, variant: ThemePreviewVariant) {
        // ImageRenderer draws 16 bits a channel; the screen shows 8. Half the
        // memory, and Core Animation draws it without converting.
        let ready = image.bitsPerPixel == 32 ? image : ImageLibrary.displayReady(image)
        if variant == .backdrop, wallpaperColors[set.id] == nil, let color = WallpaperColor.accent(of: ready) {
            wallpaperColors[set.id] = color
        }
        if let old = previews[name]?.image { bytes -= old.decodedByteCount }
        let picture = NSImage(cgImage: ready, size: NSSize(width: ready.width, height: ready.height))
        preview(name).image = picture
        bytes += picture.decodedByteCount
        useCount += 1
        lastUse[name] = useCount
        while bytes > Self.memoryLimit,
              let oldest = lastUse.filter({ previews[$0.key]?.image != nil && $0.key != name && showing[$0.key] == nil })
                  .min(by: { $0.value < $1.value })?.key {
            if let dropped = previews[oldest]?.image { bytes -= dropped.decodedByteCount }
            previews[oldest]?.image = nil
            lastUse[oldest] = nil
        }
    }

    /// Lets go of every preview in memory (they stay on disk), for when the
    /// window that shows them closes or memory runs short.
    func purge() {
        // Loads and drawings already under way finish (and still reach the
        // disk) but don't come back into memory.
        generation += 1
        queue.removeAll()
        inFlight.removeAll()
        for entry in previews.values { entry.image = nil }
        previews.removeAll()
        lastUse.removeAll()
        showing.removeAll()
        bytes = 0
    }

    /// Asks for a preview. Pictures already on disk load at once, off the main
    /// thread; the rest are drawn one at a time, in the order asked, so a page
    /// full of new cards never floods the main thread (drawing uses it).
    func request(_ set: ThemeSet, dark: Bool, variant: ThemePreviewVariant = .desktop, services: AppServices) {
        let name = key(set, dark: dark, variant: variant)
        showing[name, default: 0] += 1
        guard previews[name]?.image == nil, !inFlight.contains(name) else { return }
        inFlight.insert(name)
        let asked = generation
        Task {
            // Disk hits also decode images and update the view. A shelf entering
            // the viewport must not do that work during an active scroll.
            guard await waitUntilQuiet(name: name, generation: asked) else { return }
            if let cached = await Self.load(folder.appendingPathComponent(name + ".png")) {
                guard await waitUntilQuiet(name: name, generation: asked) else { return }
                keep(cached, as: name, of: set, variant: variant)
                inFlight.remove(name)
                return
            }
            guard asked == generation else { return }
            // Photos, cut-outs and forecasts are fetched now, for every card at
            // once; only the drawing itself waits its turn.
            let prepared = Task { await prepare(set, dark: dark, variant: variant, services: services) }
            // A backdrop is a moment's work and the whole page waits on its
            // light: ahead of the pictures that take a second each.
            if variant == .backdrop {
                queue.insert((name, set, dark, variant, prepared), at: 0)
            } else {
                queue.append((name, set, dark, variant, prepared))
            }
            drawQueued(services: services)
        }
    }

    /// A card that scrolled away no longer needs its picture drawn first.
    func cancel(_ set: ThemeSet, dark: Bool, variant: ThemePreviewVariant = .desktop) {
        let name = key(set, dark: dark, variant: variant)
        if let count = showing[name] { showing[name] = count > 1 ? count - 1 : nil }
        guard showing[name] == nil else { return }
        guard let index = queue.firstIndex(where: { $0.name == name }) else { return }
        queue.remove(at: index).prepared.cancel()
        inFlight.remove(name)
    }

    @ObservationIgnored private var scrollObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var scrollsUnderWay = 0
    @ObservationIgnored private var lastScrollEnd: CFTimeInterval = 0
    /// Mouse wheels and scrollbar drags can move without live-scroll
    /// notifications. Keep preview rendering off the main thread's next frame.
    func noteScrollMovement() { lastScrollEnd = CACurrentMediaTime() }
    /// Scrolling now, or stopped too recently for a stall to go unnoticed
    /// (a flick keeps moving for a moment after the fingers lift).
    private var isScrolling: Bool {
        scrollsUnderWay > 0 || CACurrentMediaTime() - lastScrollEnd < 0.35
    }

    func waitUntilScrollSettles() async -> Bool {
        while isScrolling {
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return false }
        }
        return !Task.isCancelled
    }

    private func waitUntilQuiet(name: String, generation asked: Int) async -> Bool {
        while asked == generation, showing[name] != nil, isScrolling {
            do { try await Task.sleep(for: .milliseconds(120)) } catch { break }
        }
        guard asked == generation else { return false }
        guard showing[name] != nil, !Task.isCancelled else {
            inFlight.remove(name)
            return false
        }
        return true
    }

    @ObservationIgnored private var queue: [(name: String, set: ThemeSet, dark: Bool, variant: ThemePreviewVariant,
                                             prepared: Task<[WidgetInstance], Never>)] = []
    @ObservationIgnored private var drawing: Task<Void, Never>?

    private func drawQueued(services: AppServices) {
        guard drawing == nil else { return }
        drawing = Task {
            while !queue.isEmpty {
                while isScrolling { try? await Task.sleep(for: .milliseconds(120)) }
                guard !queue.isEmpty else { break }
                let (name, set, dark, variant, prepared) = queue.removeFirst()
                let asked = generation
                var drawn = await render(set, dark: dark, variant: variant, widgets: await prepared.value,
                                         services: services, name: name, generation: asked)
                // Blurred and faded now, once, and saved that way: nothing is
                // blurred when the carousel moves.
                if variant == .backdrop, let sharp = drawn { drawn = await Self.softened(SendableImage(sharp))?.image }
                if let image = drawn {
                    if asked == generation { keep(image, as: name, of: set, variant: variant) }
                    let file = folder.appendingPathComponent(name + ".png"), folder = folder
                    let picture = SendableImage(image)
                    // Stale: this set's older pictures from this same build. Another
                    // build's (a debug run beside the Dock app) are left alone, or the
                    // two would delete each other's whole cache.
                    let older = "\(set.id)-\(dark ? "dark" : "light")-", build = "-\(Self.appVersion)-d\(Self.drawingVersion)-"
                    Task.detached(priority: .utility) {
                        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        // Earlier pictures of this set, of this kind (its
                        // desktop, card and backdrop are kept side by side), are stale now.
                        for stale in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
                        where stale.hasPrefix(older) && stale.contains(build) && variant.owns(stale)
                            && stale != file.lastPathComponent {
                            try? FileManager.default.removeItem(at: folder.appendingPathComponent(stale))
                        }
                        guard let destination = CGImageDestinationCreateWithURL(file as CFURL, "public.png" as CFString, 1, nil) else { return }
                        CGImageDestinationAddImage(destination, picture.image, nil)
                        CGImageDestinationFinalize(destination)
                    }
                }
                inFlight.remove(name)
                // A frame for the page between pictures.
                try? await Task.sleep(for: .milliseconds(16))
            }
            drawing = nil
        }
    }

    /// Fetches what the widgets show (photos, the forecast), so the picture
    /// never catches them still loading. Runs alongside other cards' fetches.
    private func prepare(_ set: ThemeSet, dark: Bool, variant: ThemePreviewVariant, services: AppServices) async -> [WidgetInstance] {
        // A backdrop shows the wallpaper and nothing else.
        guard variant != .backdrop else {
            if case .photo(let source) = set.wallpaper { _ = await services.images.image(for: source, maxPixels: 1200) }
            return []
        }
        let widgets = ThemeComposition.widgets(for: set, dark: dark, services: services)
        for widget in widgets {
            for image in widget.options.images { _ = await services.images.image(for: image, maxPixels: 768) }
            // Player cards stand their player on the foil, cut out ahead of time.
            if widget.kind == .playerCard, let portrait = widget.options.images.first {
                _ = await SubjectCutout.cutout(for: portrait, library: services.images)
            }
            if let location = widget.options.location {
                if widget.kind == .weather { services.weather.refreshIfNeeded(location) }
                if widget.kind == .airQuality { services.weather.refreshAirQualityIfNeeded(location) }
            }
        }
        if case .photo(let source) = set.wallpaper { _ = await services.images.image(for: source, maxPixels: 1200) }
        // Give the forecast a moment to arrive.
        for _ in 0..<20 where widgets.contains(where: { widget in
            widget.options.location.map { location in
                (widget.kind == .weather && services.weather.reports[location] == nil && services.weather.forecastFailures[location] == nil)
                    || (widget.kind == .airQuality && services.weather.airQuality[location] == nil && services.weather.airQualityFailures[location] == nil)
            } ?? false
        }) {
            try? await Task.sleep(for: .milliseconds(150))
        }
        return widgets
    }

    private func render(_ set: ThemeSet, dark: Bool, variant: ThemePreviewVariant, widgets: [WidgetInstance],
                        services: AppServices, name: String, generation asked: Int) async -> CGImage? {
        // Preparation can finish after the person changes pages. Never mount
        // a discarded preview, or draw one while the current page is scrolling.
        guard await waitUntilQuiet(name: name, generation: asked) else { return nil }
        let view: AnyView = switch variant {
        case .desktop:
            AnyView(ThemeComposition(set: set, widgets: widgets, services: services, dark: dark).frame(width: 568, height: 384))
        case .card:
            // Three quarters of the card canvas: at twice that, sharp on the
            // largest selected card.
            AnyView(ThemeCardComposition(set: set, widgets: widgets, services: services, dark: dark).frame(width: 414, height: 552))
        case .backdrop:
            AnyView(ThemeWallpaper(set: set, services: services, dark: dark)
                .frame(width: ThemePreviewVariant.backdropSize.width, height: ThemePreviewVariant.backdropSize.height)
                .clipped())
        }
        let renderer = ImageRenderer(content: view.environment(\.widgetSnapshot, true))
        renderer.scale = variant == .backdrop ? 1 : 2
        guard let image = renderer.cgImage else {
            log.error("Couldn't draw a preview of \(set.id, privacy: .public)")
            return nil
        }
        return image
    }

    #if DEBUG
    /// How many pictures have been blurred since launch, for checking that
    /// none are while the carousel moves (`-probe carousel`).
    nonisolated static let softenings = OSAllocatedUnfairLock(initialState: 0)
    #endif

    /// A wallpaper picture as the atmosphere uses it: blurred until only its
    /// light is left, and fading to nothing toward the bottom, so it melts
    /// into the page below it with no mask to apply when it's drawn.
    nonisolated private static func softened(_ picture: SendableImage) async -> SendableImage? {
        await Task.detached(priority: .utility) { () -> SendableImage? in
            #if DEBUG
            softenings.withLock { $0 += 1 }
            #endif
            let source = picture.image
            let extent = CGRect(x: 0, y: 0, width: source.width, height: source.height)
            // A blur averages colors toward gray: the picture's own are
            // strengthened first, so what's left is its light, not its mud.
            let blurred = CIImage(cgImage: source)
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.6])
                .clampedToExtent()
                .applyingGaussianBlur(sigma: Double(source.width) / 22)
                .cropped(to: extent)
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let soft = CIContext(options: [.cacheIntermediates: false]).createCGImage(blurred, from: extent, format: .RGBA8, colorSpace: space),
                  let context = CGContext(data: nil, width: source.width, height: source.height, bitsPerComponent: 8,
                                          bytesPerRow: source.width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let fade = CGGradient(colorsSpace: space,
                                        colors: [CGColor(red: 0, green: 0, blue: 0, alpha: 1), CGColor(red: 0, green: 0, blue: 0, alpha: 1),
                                                 CGColor(red: 0, green: 0, blue: 0, alpha: 0)] as CFArray,
                                        locations: [0, 0.4, 1]) else { return nil }
            context.draw(soft, in: extent)
            // Keeps what's drawn only as far as the gradient is opaque:
            // whole at the top, gone at the bottom.
            context.setBlendMode(.destinationIn)
            context.drawLinearGradient(fade, start: CGPoint(x: 0, y: extent.height), end: .zero, options: [])
            return context.makeImage().map(SendableImage.init)
        }.value
    }

    private static func load(_ file: URL) async -> CGImage? {
        await Task.detached(priority: .userInitiated) { () -> CGImage? in
            // Not drawn yet is the usual case: check first, or ImageIO logs an error per miss.
            guard FileManager.default.fileExists(atPath: file.path),
                  let source = CGImageSourceCreateWithURL(file as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
            else { return nil }
            return ImageLibrary.displayReady(image)
        }.value
    }
}
