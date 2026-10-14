import AppKit
import SwiftUI

// The one background of the main window: a deep navy canvas with soft blue
// light drifting across it, like bloom through a lens. Pages draw on top of
// it and never paint their own, so there is one backdrop, not one per page.

/// The window's canvas and its moving light.
struct WindowBackdrop: View {
    /// Holds the light still: Reduce Motion, a saving tier, a hot Mac.
    var paused: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [DS.Surface.canvasLift, DS.Surface.canvas],
                           startPoint: .top, endPoint: .init(x: 0.5, y: 0.7))
            LensGlow(paused: paused)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Soft blue glows that drift slowly. Core Animation layers, not SwiftUI
/// state: the render server moves them, so the main thread does no work per
/// frame and nothing redraws but the glows' positions. Paused (frozen in
/// place) when asked, and while the window can't be seen.
struct LensGlow: NSViewRepresentable {
    var paused: Bool

    func makeNSView(context: Context) -> LensGlowView { LensGlowView() }

    func updateNSView(_ view: LensGlowView, context: Context) {
        view.isPausedByPolicy = paused
    }
}

final class LensGlowView: NSView {
    /// The glows live in a fixed 1000 × 700 space, scaled to the view, so a
    /// resize never restarts (or jolts) their paths.
    private static let space = CGSize(width: 1000, height: 700)
    private let container = CALayer()

    var isPausedByPolicy = false {
        didSet { if isPausedByPolicy != oldValue { updatePause() } }
    }
    private var isOccluded = false {
        didSet { if isOccluded != oldValue { updatePause() } }
    }
    /// Read in `deinit`, which isn't on the main actor; only ever set on it.
    nonisolated(unsafe) private var occlusionObserver: NSObjectProtocol?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        container.anchorPoint = .zero
        container.bounds = CGRect(origin: .zero, size: Self.space)
        layer?.addSublayer(container)
        addGlows()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    deinit {
        if let occlusionObserver { NotificationCenter.default.removeObserver(occlusionObserver) }
    }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        container.position = .zero
        container.setAffineTransform(CGAffineTransform(scaleX: bounds.width / Self.space.width,
                                                       y: bounds.height / Self.space.height))
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let occlusionObserver { NotificationCenter.default.removeObserver(occlusionObserver) }
        occlusionObserver = nil
        guard let window else { return }
        isOccluded = !window.occlusionState.contains(.visible)
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let window = self.window else { return }
                self.isOccluded = !window.occlusionState.contains(.visible)
            }
        }
    }

    /// Freezes the glows where they are, and picks up from there again.
    private func updatePause() {
        let stopped = isPausedByPolicy || isOccluded
        if stopped, container.speed != 0 {
            let now = container.convertTime(CACurrentMediaTime(), from: nil)
            container.speed = 0
            container.timeOffset = now
        } else if !stopped, container.speed == 0 {
            let paused = container.timeOffset
            container.speed = 1
            container.timeOffset = 0
            container.beginTime = 0
            container.beginTime = container.convertTime(CACurrentMediaTime(), from: nil) - paused
        }
    }

    private struct Glow {
        let color: NSColor
        let alpha: CGFloat
        /// Diameter in the 1000-wide space.
        let size: CGFloat
        /// The ellipse it drifts around: centre and radii.
        let center: CGPoint
        let radii: CGSize
        let seconds: Double
        let clockwise: Bool
    }

    private func addGlows() {
        let glows = [
            // A wide, quiet blue across the top.
            Glow(color: NSColor(red: 0.18, green: 0.42, blue: 1.0, alpha: 1), alpha: 0.13, size: 900,
                 center: CGPoint(x: 360, y: 120), radii: CGSize(width: 220, height: 70), seconds: 46, clockwise: true),
            // Cyan, lower right.
            Glow(color: NSColor(red: 0.10, green: 0.72, blue: 0.95, alpha: 1), alpha: 0.10, size: 760,
                 center: CGPoint(x: 760, y: 420), radii: CGSize(width: 180, height: 120), seconds: 58, clockwise: false),
            // Indigo, lower left.
            Glow(color: NSColor(red: 0.42, green: 0.34, blue: 1.0, alpha: 1), alpha: 0.11, size: 820,
                 center: CGPoint(x: 220, y: 560), radii: CGSize(width: 160, height: 90), seconds: 52, clockwise: true),
            // The lens: a little quicker than the rest, but no brighter and
            // no smaller, so it reads as light moving, not a spot.
            Glow(color: NSColor(red: 0.45, green: 0.70, blue: 1.0, alpha: 1), alpha: 0.09, size: 680,
                 center: CGPoint(x: 640, y: 170), radii: CGSize(width: 260, height: 60), seconds: 28, clockwise: false),
        ]
        for glow in glows {
            let layer = CAGradientLayer()
            layer.type = .radial
            // A bell-shaped falloff: no bright core, no visible rim.
            let falloff: [(location: Double, strength: CGFloat)] = [(0, 1), (0.2, 0.82), (0.4, 0.55), (0.6, 0.28), (0.8, 0.09), (1, 0)]
            layer.colors = falloff.map { glow.color.withAlphaComponent(glow.alpha * $0.strength).cgColor }
            layer.locations = falloff.map { NSNumber(value: $0.location) }
            layer.startPoint = CGPoint(x: 0.5, y: 0.5)
            layer.endPoint = CGPoint(x: 1, y: 1)
            layer.bounds = CGRect(x: 0, y: 0, width: glow.size, height: glow.size * 0.72)
            layer.position = CGPoint(x: glow.center.x + glow.radii.width, y: glow.center.y)
            container.addSublayer(layer)

            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: glow.center.x - glow.radii.width, y: glow.center.y - glow.radii.height,
                                       width: glow.radii.width * 2, height: glow.radii.height * 2),
                            transform: glow.clockwise ? .identity
                                : CGAffineTransform(translationX: glow.center.x * 2, y: 0).scaledBy(x: -1, y: 1))
            let drift = CAKeyframeAnimation(keyPath: "position")
            drift.path = path
            drift.duration = glow.seconds
            drift.calculationMode = .paced
            drift.repeatCount = .infinity
            layer.add(drift, forKey: "drift")

            // A slow breath, out of step with the drift.
            let breath = CABasicAnimation(keyPath: "opacity")
            breath.fromValue = 0.75
            breath.toValue = 1
            breath.duration = glow.seconds / 4
            breath.autoreverses = true
            breath.repeatCount = .infinity
            breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(breath, forKey: "breath")
        }
    }
}

/// Where a full-bleed hero sits: under the navigation, edge to edge, with
/// the page's content overlapping its faded bottom.
struct BleedLayout: Equatable {
    /// The navigation's height above the page: the hero runs under it.
    var topInset: CGFloat
    /// What shows below the navigation.
    var visibleHeight: CGFloat
    /// The page's side margin, for the words.
    var margin: CGFloat
    /// How far the content below climbs onto the hero.
    var overlap: CGFloat = DS.Space.xxl
    /// The page below the navigation, for a hero that sizes itself.
    var viewport: CGSize = .zero

    var height: CGFloat { topInset + visibleHeight }
}

/// A page whose hero runs to the window's edges and up under the navigation,
/// with the rest of the page scrolling up over its faded bottom.
struct BleedScrollPage<Hero: View, Content: View>: View {
    /// When false (a search, a filter), the page starts below the navigation as usual.
    var showsHero = true
    @ViewBuilder var hero: (BleedLayout) -> Hero
    @ViewBuilder var content: (CGFloat) -> Content

    var body: some View {
        GeometryReader { geometry in
            let margin = DS.Space.pageMargin(for: geometry.size.width)
            let inset = geometry.safeAreaInsets.top
            let layout = BleedLayout(topInset: inset,
                                     visibleHeight: min(max(geometry.size.height * 0.62, 320), 560),
                                     margin: margin, viewport: geometry.size)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if showsHero {
                        hero(layout)
                    }
                    VStack(alignment: .leading, spacing: DS.Space.section) {
                        content(geometry.size.width)
                    }
                    .padding(.horizontal, margin)
                    .padding(.top, showsHero ? -layout.overlap : inset + DS.Space.xl)
                    .padding(.bottom, DS.Space.xxl)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

/// A canvas-colored sheet that fades away over a page that just appeared, so
/// opening a page eases in. Core Animation runs the fade on the render server:
/// SwiftUI cross-fading two whole pages re-laid-out both on every frame and
/// dropped most of them (a Themes switch held the main thread 560 ms, now ~100).
struct PageVeil: NSViewRepresentable {
    let page: AppPage?

    func makeNSView(context: Context) -> VeilView { VeilView() }

    func updateNSView(_ view: VeilView, context: Context) {
        view.show(for: page)
    }

    final class VeilView: NSView {
        private var shown: AppPage??

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.backgroundColor = NSColor(DS.Surface.canvasLift).cgColor
            layer?.opacity = 0
        }

        required init?(coder: NSCoder) { nil }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        func show(for page: AppPage?) {
            defer { shown = .some(page) }
            // The first page appears with the window, not out of a veil.
            guard let previous = shown, previous != page, let layer else { return }
            layer.removeAllAnimations()
            layer.opacity = 0
            guard !Motion.reducesMotion else { return }
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.9
            fade.toValue = 0
            fade.duration = 0.24
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(fade, forKey: "fade")
        }
    }
}
