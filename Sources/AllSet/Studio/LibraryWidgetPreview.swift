import AllSetCore
import AppKit
import CryptoKit
import SwiftUI

/// Only a hovered library card mounts a live widget. Still previews render
/// after scrolling settles and are byte-bounded, rather than kept for all 700 cards.
@MainActor enum LibraryPreviewCache {
    private static var images = CostCache<String, NSImage>(costLimit: 32 << 20, countLimit: 80)
    private static var scrolls = 0
    private static var quietAfter = Date.distantPast
    private static let observers: [NSObjectProtocol] = {
        let center = NotificationCenter.default
        return [
            center.addObserver(forName: NSScrollView.willStartLiveScrollNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { scrolls += 1 }
            },
            center.addObserver(forName: NSScrollView.didEndLiveScrollNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { scrolls = max(0, scrolls - 1); quietAfter = Date.now.addingTimeInterval(0.15) }
            }
        ]
    }()
    static func key(_ instance: WidgetInstance, fit: CGSize, services: AppServices) -> String {
        var sample = instance
        sample.id = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let data = (try? encoder.encode(sample)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            + "-\(Int(fit.width))-\(Int(fit.height))-\(services.settings.widgetFont)-\(services.settings.widgetCornerRadius)"
    }
    static func image(_ key: String) -> NSImage? { images.value(forKey: key) }
    static func clear() { images.removeAll(); scrolls = 0; quietAfter = .distantPast }
    static func boundsMoved() { quietAfter = Date.now.addingTimeInterval(0.15) }
    static func waitUntilQuiet() async -> Bool {
        _ = observers
        repeat {
            do { try await Task.sleep(for: .milliseconds(180)) } catch { return false }
        } while scrolls > 0 || Date.now < quietAfter
        return !Task.isCancelled
    }
    static func render(_ instance: WidgetInstance, fit: CGSize, services: AppServices, key: String) async -> NSImage? {
        _ = observers
        if let cached = image(key) { return cached }
        for source in instance.options.images { _ = await services.images.image(for: source, maxPixels: 640) }
        if let source = instance.options.background { _ = await services.images.image(for: source, maxPixels: 640) }
        guard await waitUntilQuiet() else { return nil }
        let content = WidgetPreview(instance: instance, services: services, fit: fit)
            .frame(width: fit.width, height: fit.height)
            .environment(\.widgetSnapshot, true).environment(\.widgetIsVisible, false)
            .environment(\.widgetIsOnScreen, false).environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: content); renderer.scale = 1.5
        guard let cg = renderer.cgImage else { return nil }
        let result = NSImage(cgImage: cg, size: fit)
        images.insert(result, forKey: key, cost: cg.bytesPerRow * cg.height)
        return result
    }
}

struct LibraryWidgetPreview: View {
    let instance: WidgetInstance
    let services: AppServices
    let fit: CGSize
    var live = false
    @State private var image: NSImage?
    var body: some View {
        let key = LibraryPreviewCache.key(instance, fit: fit, services: services)
        ZStack {
            if live {
                WidgetPreview(instance: instance, services: services, fit: fit)
                    .environment(\.widgetIsVisible, true)
            } else if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: instance.kind.symbol).font(.system(size: 32)).foregroundStyle(.white.opacity(0.25))
            }
        }.frame(width: fit.width, height: fit.height)
        .allowsHitTesting(false)
        .task(id: key) {
            image = LibraryPreviewCache.image(key)
            if image == nil { image = await LibraryPreviewCache.render(instance, fit: fit, services: services, key: key) }
        }
    }
}

/// Also catches mouse wheels and scrollbar drags, which do not always send
/// trackpad live-scroll notifications. No polling and no per-card observers.
struct LibraryScrollActivity: NSViewRepresentable {
    var onBoundsChange: @MainActor () -> Void = {}
    func makeNSView(context: Context) -> Watcher { Watcher() }
    func updateNSView(_ view: Watcher, context: Context) { view.onBoundsChange = onBoundsChange }
    final class Watcher: NSView {
        var onBoundsChange: @MainActor () -> Void = {}
        // Installed on the main actor; NotificationCenter removal is safe
        // during nonisolated NSView teardown, as with CinemaWindowPresence.
        nonisolated(unsafe) private var token: NSObjectProtocol?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let token { NotificationCenter.default.removeObserver(token); self.token = nil }
            guard window != nil, let clip = enclosingScrollView?.contentView else { return }
            clip.postsBoundsChangedNotifications = true
            token = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: clip, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    LibraryPreviewCache.boundsMoved()
                    self?.onBoundsChange()
                }
            }
        }
        deinit { if let token { NotificationCenter.default.removeObserver(token) } }
    }
}
