import AllSetCore
import AppKit
import CoreImage
import SwiftUI

// Live effects for the glowing widgets: a pulsing glow, artwork that floats
// with light sweeping across it, equalizer bars, blinking lights, a VHS
// tracking band, a ball in play and sparkles. All of it runs in Core
// Animation, outside the app, so a widget that moves all day costs the app
// nothing between changes. Each stops when the widget is covered or Reduce
// Motion is on, and draws a still SwiftUI version for snapshots, which can't
// capture AppKit views.

extension EnvironmentValues {
    /// How much larger than its layout a widget is drawn on the desktop, so
    /// pictures made of it can be made at the resolution they're shown at.
    @Entry var widgetRenderScale: CGFloat = 1
}

/// A layer-backed view whose sublayers sit in `root`, with y pointing down
/// like SwiftUI. Subclasses lay out in `build` and animate in `refresh`.
class LiveLayerView: NSView {
    let root = CALayer()
    var isRunning = false {
        didSet { if isRunning != oldValue { refresh() } }
    }
    private var builtSize = CGSize.zero

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
        root.isGeometryFlipped = true
        root.actions = ["bounds": NSNull(), "position": NSNull()]
        layer?.addSublayer(root)
    }

    required init?(coder: NSCoder) { nil }

    /// Clicks and drags belong to the widget.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        guard bounds.size != builtSize, bounds.width > 0, bounds.height > 0 else { return }
        builtSize = bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.frame = bounds
        build(in: CGRect(origin: .zero, size: bounds.size))
        CATransaction.commit()
        refresh()
    }

    /// Lays out the sublayers for the view's size.
    func build(in bounds: CGRect) {}

    /// Adds or removes the animations to match `isRunning`.
    func refresh() {}

    /// Lays out again, after a change that needs new sublayers.
    func rebuild() {
        builtSize = .zero
        needsLayout = true
    }

    /// An animation that repeats forever, even across the window hiding. Slow
    /// motion asks for fewer frames: the window server then composites the
    /// widget a third as often as at the display's full rate.
    static func loop(_ keyPath: String, from: Any, to: Any, duration: Double, autoreverses: Bool = true,
                     offset: Double = 0, timing: CAMediaTimingFunctionName = .easeInEaseOut, fps: Float = 20) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.preferredFrameRateRange = rate(fps)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.autoreverses = autoreverses
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: timing)
        animation.beginTime = CACurrentMediaTime() - offset
        animation.isRemovedOnCompletion = false
        return animation
    }

    static func rate(_ fps: Float) -> CAFrameRateRange {
        #if DEBUG
        // `-uncapped YES`: the display's full rate, for measuring what the caps save.
        if UserDefaults.standard.bool(forKey: "uncapped") { return .default }
        #endif
        return CAFrameRateRange(minimum: max(fps / 2, 8), maximum: fps, preferred: fps)
    }

    /// A stable pseudo-random number in 0..<1.
    static func random(_ index: Int, _ salt: Int) -> Double {
        let x = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43_758.5453
        return x - x.rounded(.down)
    }
}

// MARK: Pulsing glow

/// A soft pool of light that swells and fades, behind something that glows.
struct PulsingGlow: View {
    let color: Color
    var period = 3.4
    var intensity = 1.0
    @Environment(\.widgetSnapshot) private var snapshot
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if snapshot {
            GeometryReader { geometry in
                RadialGradient(colors: [color.opacity(0.55 * intensity), color.opacity(0.18 * intensity), .clear],
                               center: .center, startRadius: 0, endRadius: max(geometry.size.width, geometry.size.height) / 2)
            }
        } else {
            PulsingGlowLayer(color: NSColor(color).cgColor, period: period, intensity: intensity,
                             isRunning: isVisible && !reduceMotion)
        }
    }
}

struct PulsingGlowLayer: NSViewRepresentable {
    let color: CGColor
    let period: Double
    let intensity: Double
    let isRunning: Bool

    func makeNSView(context: Context) -> GlowView { GlowView() }

    func updateNSView(_ view: GlowView, context: Context) {
        view.configure(color: color, period: period, intensity: intensity)
        view.isRunning = isRunning
    }

    final class GlowView: LiveLayerView {
        private let gradient = CAGradientLayer()
        private var period = 3.4

        override init() {
            super.init()
            gradient.type = .radial
            gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 1)
            gradient.locations = [0, 0.45, 1]
            root.addSublayer(gradient)
        }

        required init?(coder: NSCoder) { nil }

        func configure(color: CGColor, period: Double, intensity: Double) {
            let colors = [color.copy(alpha: 0.55 * intensity), color.copy(alpha: 0.18 * intensity), color.copy(alpha: 0)]
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            gradient.colors = colors.compactMap { $0 }
            CATransaction.commit()
            if period != self.period {
                self.period = period
                refresh()
            }
        }

        override func build(in bounds: CGRect) {
            gradient.frame = bounds
        }

        override func refresh() {
            gradient.removeAllAnimations()
            guard isRunning else { return }
            gradient.add(Self.loop("opacity", from: 0.55, to: 1, duration: period / 2), forKey: "breathe")
            gradient.add(Self.loop("transform.scale", from: 0.94, to: 1.06, duration: period / 2), forKey: "swell")
        }
    }
}

// MARK: Floating artwork

/// A drawing that floats gently, glows, and now and then catches a sweep of
/// light across its surface. Until it will actually move (on screen, motion
/// allowed) it's plain SwiftUI; then it's drawn once into a picture, shared
/// through `ArtworkCache`, that Core Animation moves. The glow is blurred off
/// the main thread, at half size.
struct LiveArtwork<Content: View, Key: Hashable>: View {
    let key: Key
    var glow: Color?
    var glowRadius: CGFloat = 16
    var float = true
    var shine = true
    var shinePeriod = 6.0
    @ViewBuilder let content: () -> Content

    @Environment(\.widgetSnapshot) private var snapshot
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @Environment(\.widgetRenderScale) private var renderScale
    @State private var rendered: ArtworkCache.Artwork?
    @State private var failed = false

    private struct RenderID: Hashable {
        let key: Key
        let size: CGSize
        let glow: String
        let glowRadius: CGFloat
        let scale: CGFloat
    }

    var body: some View {
        GeometryReader { geometry in
            let id = RenderID(key: key, size: geometry.size, glow: glow.map { "\($0)" } ?? "", glowRadius: glowRadius,
                              scale: max(displayScale, 2) * max(renderScale, 1))
            let artwork = rendered?.id == AnyHashable(id) ? rendered : ArtworkCache.artwork(for: id)
            Group {
                if !snapshot, let artwork {
                    LiveArtworkLayer(image: artwork.image, glow: artwork.glow, padding: padding,
                                     float: float, shine: shine, shinePeriod: shinePeriod,
                                     isRunning: isVisible && !reduceMotion)
                } else if wantsMotion, !failed {
                    // Its picture is a frame or two away: drawing it here first,
                    // blurred glow and all, would cost more than the wait.
                    Color.clear
                } else {
                    content()
                        .shadow(color: glow?.opacity(0.8) ?? .clear, radius: glowRadius * 0.6)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            // Drawn only once it will move: still previews never pay for it.
            .task(id: wantsMotion && geometry.size.width > 0 ? id : nil) {
                guard wantsMotion, geometry.size.width > 0, ArtworkCache.artwork(for: id) == nil else { return }
                rendered = await render(id: id, size: geometry.size)
                failed = rendered == nil && !Task.isCancelled
            }
        }
    }

    private var wantsMotion: Bool { !snapshot && isVisible && !reduceMotion }

    /// Room around the drawing for the glow to spread into.
    private var padding: CGFloat { glow == nil ? 2 : glowRadius * 1.6 }

    private func render(id: RenderID, size: CGSize) async -> ArtworkCache.Artwork? {
        let renderer = ImageRenderer(content: content()
            .frame(width: size.width, height: size.height)
            .padding(padding))
        renderer.scale = id.scale
        // Kept as 8-bit screen-ready pixels: ImageRenderer's 16-bit output
        // would take twice the memory for nothing a screen can show.
        guard let image = renderer.cgImage.map(ImageLibrary.displayReady) else { return nil }
        var glowImage: CGImage?
        if let glow, let color = CIColor(color: NSColor(glow)) {
            let radius = glowRadius * id.scale * 0.5
            let source = SendableImage(image)
            glowImage = await Task.detached(priority: .userInitiated) {
                ArtworkCache.glowImage(from: source.image, color: color, radius: radius).map(SendableImage.init)
            }.value?.image
        }
        guard !Task.isCancelled else { return nil }
        let artwork = ArtworkCache.Artwork(id: AnyHashable(id), image: image, glow: glowImage)
        ArtworkCache.store(artwork)
        return artwork
    }
}

/// A CGImage passed to a background task; CGImages are immutable.
struct SendableImage: @unchecked Sendable {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

/// Drawn artwork shared by every widget and window that shows the same thing
/// at the same size, so reopening or re-applying never draws it again.
@MainActor
enum ArtworkCache {
    struct Artwork {
        let id: AnyHashable
        let image: CGImage
        let glow: CGImage?
    }

    /// Widget-sized pictures and their glows, least recently used first out,
    /// limited by bytes as well as count.
    private static var artworks = CostCache<AnyHashable, Artwork>(costLimit: 64 << 20, countLimit: 60)

    #if DEBUG
    static var debugCacheReport: String {
        String(format: "artworks %d (%.0f MB)", artworks.count, Double(artworks.totalCost) / 1_048_576)
    }
    #endif

    static func artwork(for id: AnyHashable) -> Artwork? { artworks.value(forKey: id) }

    static func store(_ artwork: Artwork) {
        let cost = artwork.image.bytesPerRow * artwork.image.height + (artwork.glow.map { $0.bytesPerRow * $0.height } ?? 0)
        artworks.insert(artwork, forKey: artwork.id, cost: cost)
    }

    /// Lets go of cached artwork down to `fraction` of the limit (0 empties
    /// it); widgets that are moving keep their layers' copies.
    static func trim(to fraction: Double) {
        artworks.trim(toCost: Int(Double(artworks.costLimit) * fraction))
    }

    /// One context for every glow: making one costs more than the blur.
    nonisolated private static let context = CIContext(options: [.useSoftwareRenderer: false, .cacheIntermediates: false])

    /// The drawing's silhouette in the glow color, blurred, at half size
    /// (it's a blur: nobody sees the difference, and it's a quarter of the pixels).
    nonisolated static func glowImage(from image: CGImage, color: CIColor, radius: CGFloat) -> CGImage? {
        let source = CIImage(cgImage: image)
        let tinted = CIImage(color: color).cropped(to: source.extent)
            .applyingFilter("CISourceInCompositing", parameters: [kCIInputBackgroundImageKey: source])
            .transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
        let extent = CGRect(x: 0, y: 0, width: source.extent.width / 2, height: source.extent.height / 2)
        let blurred = tinted.clampedToExtent().applyingGaussianBlur(sigma: radius / 2).cropped(to: extent)
        return context.createCGImage(blurred, from: extent)
    }
}

struct LiveArtworkLayer: NSViewRepresentable {
    let image: CGImage
    let glow: CGImage?
    let padding: CGFloat
    let float: Bool
    let shine: Bool
    let shinePeriod: Double
    let isRunning: Bool

    func makeNSView(context: Context) -> ArtworkView { ArtworkView() }

    func updateNSView(_ view: ArtworkView, context: Context) {
        view.configure(self)
        view.isRunning = isRunning
    }

    final class ArtworkView: LiveLayerView {
        private let holder = CALayer()
        private let glowLayer = CALayer()
        private let imageLayer = CALayer()
        private let shineLayer = CAGradientLayer()
        private let shineMask = CALayer()
        private var padding: CGFloat = 0
        private var float = true
        private var shine = true
        private var shinePeriod = 6.0

        override init() {
            super.init()
            for sublayer in [glowLayer, imageLayer, shineMask] {
                sublayer.contentsGravity = .resize
                sublayer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
            }
            shineLayer.colors = [NSColor(white: 1, alpha: 0).cgColor, NSColor(white: 1, alpha: 0.5).cgColor,
                                 NSColor(white: 1, alpha: 0).cgColor]
            shineLayer.startPoint = CGPoint(x: 0, y: 0.25)
            shineLayer.endPoint = CGPoint(x: 1, y: 0.75)
            shineLayer.locations = [-0.4, -0.25, -0.1]
            shineLayer.mask = shineMask
            holder.addSublayer(glowLayer)
            holder.addSublayer(imageLayer)
            holder.addSublayer(shineLayer)
            root.addSublayer(holder)
        }

        required init?(coder: NSCoder) { nil }

        func configure(_ artwork: LiveArtworkLayer) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if (imageLayer.contents as AnyObject?) !== artwork.image {
                imageLayer.contents = artwork.image
                shineMask.contents = artwork.image
            }
            if (glowLayer.contents as AnyObject?) !== artwork.glow { glowLayer.contents = artwork.glow }
            glowLayer.isHidden = artwork.glow == nil
            shineLayer.isHidden = !artwork.shine
            CATransaction.commit()
            let changed = artwork.padding != padding || artwork.float != float || artwork.shine != shine
                || artwork.shinePeriod != shinePeriod
            padding = artwork.padding
            float = artwork.float
            shine = artwork.shine
            shinePeriod = artwork.shinePeriod
            if changed { rebuild() }
        }

        override func build(in bounds: CGRect) {
            holder.frame = bounds
            let frame = bounds.insetBy(dx: -padding, dy: -padding)
            for sublayer in [glowLayer, imageLayer, shineLayer] { sublayer.frame = frame }
            shineMask.frame = CGRect(origin: .zero, size: frame.size)
        }

        override func refresh() {
            holder.removeAllAnimations()
            glowLayer.removeAllAnimations()
            shineLayer.removeAllAnimations()
            glowLayer.opacity = 0.85
            guard isRunning else { return }
            if float {
                holder.add(Self.loop("transform.translation.y", from: -2.5, to: 2.5, duration: 3.4), forKey: "float")
                holder.add(Self.loop("transform.rotation.z", from: -0.007, to: 0.007, duration: 5.1, offset: 1.3), forKey: "sway")
            }
            glowLayer.add(Self.loop("opacity", from: 0.55, to: 1, duration: 2.6), forKey: "glow")
            if shine {
                let sweep = CABasicAnimation(keyPath: "locations")
                sweep.fromValue = [-0.4, -0.25, -0.1]
                sweep.toValue = [1.1, 1.25, 1.4]
                sweep.duration = 1.4
                sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                let group = CAAnimationGroup()
                group.animations = [sweep]
                group.duration = max(shinePeriod, 2)
                group.repeatCount = .infinity
                group.beginTime = CACurrentMediaTime() + 0.8
                group.preferredFrameRateRange = Self.rate(30)
                group.isRemovedOnCompletion = false
                shineLayer.add(group, forKey: "shine")
            }
        }
    }
}

// MARK: Equalizer

/// Bars that dance while music plays and breathe slowly while it doesn't.
struct EqualizerBars: View {
    let style: VisualizerStyle
    let colors: [Color]
    let isPlaying: Bool
    var count = 28
    @Environment(\.widgetSnapshot) private var snapshot
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if snapshot {
            Canvas { context, size in
                EqualizerBarsLayer.BarsView.stillBars(style: style, count: count, size: size) { rect, angle, center in
                    var bar = context
                    if let angle, let center {
                        bar.translateBy(x: center.x, y: center.y)
                        bar.rotate(by: .radians(angle))
                        bar.translateBy(x: -center.x, y: -center.y)
                    }
                    bar.fill(Path(roundedRect: rect, cornerRadius: rect.width / 2),
                             with: .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: rect.midX, y: rect.maxY),
                                                   endPoint: CGPoint(x: rect.midX, y: rect.minY)))
                }
            }
        } else {
            EqualizerBarsLayer(style: style, colors: colors.map { NSColor($0).cgColor }, count: count,
                               isPlaying: isPlaying, isRunning: isVisible && !reduceMotion)
        }
    }
}
