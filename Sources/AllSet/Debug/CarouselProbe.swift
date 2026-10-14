#if DEBUG
import AllSetCore
import AppKit
import OSLog
import SwiftUI

extension PageCPUProbe {
    /// `-probe carousel`: scrolls over the Themes hero the way a trackpad and
    /// a wheel do, and reports where each gesture went. Sideways ones should
    /// move the carousel and land it on a card; the rest should scroll the
    /// page. The pointer isn't touched: the events are made here and handed
    /// to the view that would get them. Run it again with Reduce Motion on
    /// to check the dissolve path lands on the same cards.
    static func runCarousel(services: AppServices) async {
        let state = ThemeHeroState(), atmosphere = ThemeAtmosphereState()
        let items = Array(ThemeDiscovery.featured.sets(stats: services.themeStats).prefix(8))
        let size = CGSize(width: 1280, height: 800)
        let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: 40, y: 40), size: size),
                              styleMask: [.titled, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.alphaValue = 0.01
        window.ignoresMouseEvents = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        // The hero as the Themes page shows it, above enough page to scroll.
        let layout = BleedLayout(topInset: 0, visibleHeight: 400, margin: 32, viewport: size)
        let controller = NSHostingController(rootView: ScrollView {
            VStack(spacing: 0) {
                ThemesHero(items: items, services: services, state: state, atmosphere: atmosphere,
                           layout: layout)
                Color.clear.frame(height: 3000)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(DS.Surface.canvas))
        controller.sizingOptions = []
        window.contentViewController = controller
        window.setContentSize(size)
        window.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(3))
        defer { window.close() }

        guard let catcher = find(CarouselScrollCatcher.CatcherView.self, in: window.contentView),
              let page = tallestScrollView(in: window.contentView) else {
            print("carousel FAIL  setup: no carousel or page scroll view in the window")
            return
        }
        var failures = 0
        func check(_ name: String, _ passed: Bool, _ detail: String) {
            print("carousel \(passed ? "PASS" : "FAIL")  \(name): \(detail)")
            if !passed { failures += 1 }
        }
        // Every theme's backdrop is made (blurred once) as the hero opens.
        // Once they're all in, nothing more may be blurred, whatever the
        // carousel does: counted here and checked at the end.
        let cache = services.themePreviews
        for _ in 0..<300 where items.contains(where: { cache.image(for: $0, dark: $0.isDark, variant: .backdrop) == nil }) {
            try? await Task.sleep(for: .milliseconds(100))
        }
        let ready = items.filter { cache.image(for: $0, dark: $0.isDark, variant: .backdrop) != nil }.count
        check("every theme's backdrop is ready before the carousel moves", ready == items.count, "\(ready) of \(items.count)")
        let blurred = ThemePreviewCache.softenings.withLock { $0 }
        func offset() -> Int { Int(page.contentView.bounds.origin.y.rounded()) }
        func send(_ events: [NSEvent?]) async {
            for event in events.compactMap({ $0 }) {
                catcher.scrollWheel(with: event)
                try? await Task.sleep(for: .milliseconds(12))
            }
            // Longer than the landing takes.
            try? await Task.sleep(for: .milliseconds(650))
        }
        func top() async {
            page.contentView.scroll(to: .zero)
            page.reflectScrolledClipView(page.contentView)
            try? await Task.sleep(for: .milliseconds(50))
        }

        // The checks below mean nothing unless these read to AppKit as what they imitate.
        let began = scroll(dx: -20, phase: .began), ended = scroll(phase: .ended)
        let glide = scroll(dx: -5, glide: 2), notch = scroll(dx: -1, wheel: true)
        check("events read as made",
              began?.phase == .began && began?.hasPreciseScrollingDeltas == true && began?.scrollingDeltaX == -20
                  && ended?.phase == .ended && glide?.phase.isEmpty == true && glide?.momentumPhase == .changed
                  && notch?.phase.isEmpty == true && notch?.momentumPhase.isEmpty == true && (notch?.scrollingDeltaX ?? 0) < 0,
              "began \(began?.phase.rawValue ?? 99) dx \(began?.scrollingDeltaX ?? 0), ended \(ended?.phase.rawValue ?? 99), "
                  + "glide \(glide?.momentumPhase.rawValue ?? 99), notch dx \(notch?.scrollingDeltaX ?? 0)")

        // Which view a scroll over the middle of the carousel is sent to, and
        // which a click is. Asked while a scroll event is the app's current
        // event, as the catcher's hit-testing depends on that.
        let spot = catcher.convert(CGPoint(x: catcher.bounds.midX, y: catcher.bounds.midY), to: nil)
        func hit() -> NSView? {
            guard let content = window.contentView else { return nil }
            return content.hitTest(content.superview?.convert(spot, from: nil) ?? spot)
        }
        let seen = HitRecord()
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { _ in
            MainActor.assumeIsolated {
                seen.asked = true
                seen.view = hit()
            }
            return nil
        }
        if let notch { NSApp.postEvent(notch, atStart: false) }
        try? await Task.sleep(for: .milliseconds(300))
        if let monitor { NSEvent.removeMonitor(monitor) }
        if seen.asked {
            check("a scroll over the carousel is sent to it", seen.view === catcher, "sent to \(seen.view.map { String(describing: type(of: $0)) } ?? "nothing")")
        } else {
            print("carousel SKIP  a scroll over the carousel is sent to it: the made-up event never reached the app's queue")
        }
        // A click must land exactly where it would with no catcher there at all.
        let clicked = hit()
        catcher.isHidden = true
        let without = hit()
        catcher.isHidden = false
        check("a click there goes through to the card", clicked != nil && clicked === without,
              "sent to \(clicked.map { String(describing: type(of: $0)) } ?? "nothing"), the same view as with no catcher: \(clicked === without)")

        for reduced in [false, true] {
            services.ui.performance.reducesMotion = reduced
            let mode = reduced ? "reduce motion, " : ""
            try? await Task.sleep(for: .milliseconds(200))

            // A wheel: up and down scrolls the page, sideways steps a card.
            await top()
            let start = state.index
            await send(Array(repeating: scroll(dy: -3, wheel: true), count: 3))
            check(mode + "wheel down scrolls the page", offset() > 0 && state.index == start, "page at \(offset()), card \(state.index)")
            await top()
            await send([scroll(dx: -1, wheel: true)])
            check(mode + "wheel sideways steps a card", state.index == start + 1 && offset() == 0, "card \(state.index), page at \(offset())")
            await send([scroll(dx: 1, wheel: true)])
            check(mode + "and back", state.index == start, "card \(state.index)")
            // The row goes round: back from the first theme is the last.
            await send([scroll(dx: 1, wheel: true)])
            check(mode + "back from the first card is the last", state.index == items.count - 1, "card \(state.index) of \(items.count)")
            await send([scroll(dx: -1, wheel: true)])
            check(mode + "and on from the last is the first", state.index == start, "card \(state.index)")

            // A swipe let go slowly lands on the nearest card; the glide after it is ignored.
            await send([scroll(dx: -30, phase: .began)] + Array(repeating: scroll(dx: -30, phase: .changed), count: 9)
                       + Array(repeating: scroll(dx: -1, phase: .changed), count: 6) + [scroll(phase: .ended)])
            check(mode + "a slow swipe lands on the next card", state.index == start + 1 && offset() == 0, "card \(state.index), page at \(offset())")
            await send(Array(repeating: scroll(dx: -10, glide: 2), count: 5) + [scroll(glide: 3)])
            check(mode + "its glide moves nothing", state.index == start + 1 && offset() == 0, "card \(state.index), page at \(offset())")

            // A flick carries further, two cards at most.
            await send([scroll(dx: -40, phase: .began)] + Array(repeating: scroll(dx: -40, phase: .changed), count: 3) + [scroll(phase: .ended)])
            check(mode + "a flick carries two cards", state.index == start + 3, "card \(state.index)")

            // A vertical swipe is the page's, and the carousel stays put.
            await send([scroll(dy: -30, phase: .began)] + Array(repeating: scroll(dy: -30, phase: .changed), count: 8) + [scroll(phase: .ended)])
            let scrolled = offset()
            check(mode + "a vertical swipe scrolls the page", scrolled > 0 && state.index == start + 3, "page at \(scrolled), card \(state.index)")

            // A sideways swipe that drifts downward stays the carousel's.
            await send([scroll(dx: -30, phase: .began)] + Array(repeating: scroll(dx: -2, dy: -30, phase: .changed), count: 6) + [scroll(phase: .ended)])
            check(mode + "a drifting swipe doesn't scroll the page", offset() == scrolled && state.index == start + 3, "page at \(offset()), card \(state.index)")

            // Fingers resting, then lifted: nothing.
            await send([scroll(phase: .mayBegin), scroll(phase: .cancelled)])
            check(mode + "resting fingers do nothing", offset() == scrolled && state.index == start + 3, "page at \(offset()), card \(state.index)")

            // Back to the first card for the next pass.
            for _ in 0..<3 { await send([scroll(dx: 1, wheel: true)]) }
        }
        services.ui.performance.reducesMotion = false
        let since = ThemePreviewCache.softenings.withLock { $0 } - blurred
        check("nothing was blurred while the carousel moved", since == 0 && atmosphere.current?.id == items[state.index].id,
              "\(since) blurred, atmosphere on \(atmosphere.current?.name ?? "nothing"), carousel on \(items[state.index].name)")
        // A new preview must not invalidate another card's unchanged image.
        // Purging must still notify that card and allow it to request again.
        if items.count >= 2 {
            let isolated = ThemePreviewCache(photos: services.themePhotos)
            let first = items[0], second = items[1]
            func waitFor(_ set: ThemeSet) async -> Bool {
                for _ in 0..<100 {
                    if isolated.image(for: set, dark: set.isDark) != nil { return true }
                    try? await Task.sleep(for: .milliseconds(100))
                }
                return false
            }
            isolated.request(first, dark: first.isDark, services: services)
            let firstReady = await waitFor(first)
            let changed = OSAllocatedUnfairLock(initialState: false)
            withObservationTracking {
                _ = isolated.image(for: first, dark: first.isDark)
            } onChange: {
                changed.withLock { $0 = true }
            }
            isolated.request(second, dark: second.isDark, services: services)
            let secondReady = await waitFor(second)
            check("loading a different preview leaves the observed card alone",
                  firstReady && secondReady && !changed.withLock { $0 }, "both loaded; observer changed: \(changed.withLock { $0 })")
            isolated.cancel(first, dark: first.isDark)
            isolated.cancel(second, dark: second.isDark)
            isolated.purge()
            check("purging notifies the observed preview", changed.withLock { $0 }, "observer notified: \(changed.withLock { $0 })")
            isolated.request(first, dark: first.isDark, services: services)
            let reloaded = await waitFor(first)
            check("a purged preview loads again", reloaded, "reloaded: \(reloaded)")
            isolated.cancel(first, dark: first.isDark)
            isolated.purge()
        }
        print("carousel \(failures == 0 ? "all checks passed" : "\(failures) check(s) FAILED")")
    }

    /// What the hit test said, kept for after the event has gone by.
    private final class HitRecord {
        var asked = false
        var view: NSView?
    }

    private enum ScrollPhase: Int64 {
        case none = 0, began = 1, changed = 2, ended = 4, cancelled = 8, mayBegin = 128
    }

    /// A scroll event as a trackpad (points, with a phase or a glide phase)
    /// or a wheel (lines) would send it.
    private static func scroll(dx: Int32 = 0, dy: Int32 = 0, phase: ScrollPhase = .none, glide: Int64 = 0, wheel: Bool = false) -> NSEvent? {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: wheel ? .line : .pixel, wheelCount: 2,
                                  wheel1: dy, wheel2: dx, wheel3: 0) else { return nil }
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase.rawValue)
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: glide)
        return NSEvent(cgEvent: event)
    }

    private static func find<T: NSView>(_ type: T.Type, in view: NSView?) -> T? {
        guard let view else { return nil }
        if let match = view as? T { return match }
        for child in view.subviews {
            if let match = find(type, in: child) { return match }
        }
        return nil
    }
}
#endif
