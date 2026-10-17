import AllSetCore
import AppKit
import SwiftUI

// Widgets from the dark, glowy desktop setups people share: a hypnotic
// spiral, chrome charms, a perfume label, and a little magic (aura, tarot,
// star sign, a magic ball, a candle). Everything that moves runs in Core
// Animation (`LiveLayerView`), so it costs the app nothing between frames,
// stops when covered, and draws a still SwiftUI version for snapshots.

// MARK: Spiral

struct SpiralWidget: View {
    let instance: WidgetInstance

    var body: some View {
        let ink = instance.options.ink.map { Color($0) } ?? .white
        ZStack {
            Color(instance.tint)
            // Big enough to reach every corner of the card, which clips it.
            TurningSpiral(ink: ink, turns: instance.size == .small ? 7 : 10)
            RadialGradient(colors: [.clear, Color(instance.tint).opacity(0.55)], center: .center,
                           startRadius: 20, endRadius: instance.size == .small ? 110 : 220)
                .allowsHitTesting(false)
        }
    }
}

struct TurningSpiral: View {
    let ink: Color
    let turns: Int
    @Environment(\.widgetSnapshot) private var snapshot
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if snapshot {
            Canvas { context, size in
                let radius = hypot(size.width, size.height) / 2
                context.stroke(SpiralPath.path(center: CGPoint(x: size.width / 2, y: size.height / 2), radius: radius, turns: turns),
                               with: .color(ink), lineWidth: radius / CGFloat(turns) / 4)
            }
        } else {
            SpiralLayer(ink: NSColor(ink).cgColor, turns: turns, isRunning: isVisible && !reduceMotion)
        }
    }
}

enum SpiralPath {
    /// Two interleaved Archimedean arms: turned, the stripes seem to pour
    /// endlessly into the middle.
    static func path(center: CGPoint, radius: CGFloat, turns: Int) -> Path {
        var path = Path()
        let end = Double(turns) * 2 * .pi
        for arm in 0..<2 {
            let phase = Double(arm) * .pi
            var angle = 0.0
            path.move(to: center)
            while angle <= end {
                let r = radius * CGFloat(angle / end)
                path.addLine(to: CGPoint(x: center.x + r * CGFloat(cos(angle + phase)), y: center.y + r * CGFloat(sin(angle + phase))))
                angle += 0.06
            }
        }
        return path
    }
}

struct SpiralLayer: NSViewRepresentable {
    let ink: CGColor
    let turns: Int
    let isRunning: Bool

    func makeNSView(context: Context) -> SpiralView { SpiralView() }

    func updateNSView(_ view: SpiralView, context: Context) {
        view.configure(ink: ink, turns: turns)
        view.isRunning = isRunning
    }

    final class SpiralView: LiveLayerView {
        private let shape = CAShapeLayer()
        private var turns = 7

        override init() {
            super.init()
            shape.fillColor = nil
            shape.lineCap = .round
            // Only turned, never redrawn: one picture the window server spins.
            shape.shouldRasterize = true
            root.addSublayer(shape)
            layer?.masksToBounds = true
        }

        required init?(coder: NSCoder) { nil }

        func configure(ink: CGColor, turns: Int) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            shape.strokeColor = ink
            CATransaction.commit()
            if turns != self.turns {
                self.turns = turns
                rebuild()
            }
        }

        override func build(in bounds: CGRect) {
            let radius = hypot(bounds.width, bounds.height) / 2
            shape.frame = CGRect(x: bounds.midX - radius, y: bounds.midY - radius, width: radius * 2, height: radius * 2)
            shape.path = SpiralPath.path(center: CGPoint(x: radius, y: radius), radius: radius, turns: turns).cgPath
            shape.lineWidth = radius / CGFloat(turns) / 4
            shape.rasterizationScale = (window?.backingScaleFactor ?? 2)
        }

        override func refresh() {
            shape.removeAllAnimations()
            guard isRunning else { return }
            shape.add(Self.loop("transform.rotation.z", from: 0, to: -2 * Double.pi, duration: 9, autoreverses: false,
                                timing: .linear, fps: 30), forKey: "turn")
        }
    }
}

// MARK: Charm

struct CharmWidget: View {
    let instance: WidgetInstance

    var body: some View {
        let tint = Color(instance.tint)
        ZStack {
            LiveArtwork(key: "charm|\(instance.options.charm)|\(instance.tint)|\(instance.size)",
                        glow: tint.mix(.white, 0.5).opacity(0.7), glowRadius: 14, float: true, shine: true, shinePeriod: 5) {
                ChromeCharm(charm: instance.options.charm, tint: tint)
            }
            Sparkles(color: .white, density: 0.5)
                .padding(instance.size == .small ? 14 : 22)
        }
    }
}

/// A charm in polished metal, tinted a little by `tint`.
struct ChromeCharm: View {
    let charm: CharmShape
    let tint: Color

    var body: some View {
        let shape = CharmOutline(charm: charm)
        ZStack {
            shape.fill(LinearGradient(stops: [
                .init(color: .white, location: 0),
                .init(color: tint.mix(.white, 0.35), location: 0.28),
                .init(color: tint.mix(Color(hex: 0x252A36), 0.8), location: 0.5),
                .init(color: tint.mix(.white, 0.6), location: 0.64),
                .init(color: tint.mix(Color(hex: 0x5A6275), 0.6), location: 1),
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
            shape.fill(EllipticalGradient(colors: [.white.opacity(0.8), .clear], center: UnitPoint(x: 0.32, y: 0.24),
                                          startRadiusFraction: 0, endRadiusFraction: 0.32))
                .blendMode(.screen)
            shape.stroke(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.15), .white.opacity(0.5)],
                                        startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
        .padding(12)
    }
}

/// The outline of each charm, in the largest square that fits.
struct CharmOutline: Shape {
    let charm: CharmShape

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let r = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * side, y: r.minY + y * side) }
        func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat, degrees: CGFloat = 0) -> Path {
            let center = pt(cx, cy)
            let oval = Path(ellipseIn: CGRect(x: center.x - w * side / 2, y: center.y - h * side / 2, width: w * side, height: h * side))
            let turn = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: degrees * .pi / 180)
                .translatedBy(x: -center.x, y: -center.y)
            return oval.applying(turn)
        }
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, corner: CGFloat = 0.02) -> Path {
            Path(roundedRect: CGRect(x: r.minX + x * side, y: r.minY + y * side, width: w * side, height: h * side),
                 cornerRadius: corner * side)
        }
        let mirror = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 2 * r.midX, ty: 0)

        switch charm {
        case .heart:
            var path = Path()
            path.move(to: pt(0.5, 0.9))
            path.addCurve(to: pt(0.06, 0.36), control1: pt(0.3, 0.76), control2: pt(0.06, 0.58))
            path.addCurve(to: pt(0.5, 0.24), control1: pt(0.06, 0.08), control2: pt(0.42, 0.06))
            path.addCurve(to: pt(0.94, 0.36), control1: pt(0.58, 0.06), control2: pt(0.94, 0.08))
            path.addCurve(to: pt(0.5, 0.9), control1: pt(0.94, 0.58), control2: pt(0.7, 0.76))
            path.closeSubpath()
            return path
        case .star:
            var path = Path()
            for index in 0..<10 {
                let angle = -Double.pi / 2 + Double(index) * .pi / 5
                let radius = index.isMultiple(of: 2) ? 0.46 : 0.2
                let point = pt(0.5 + CGFloat(cos(angle) * radius), 0.53 + CGFloat(sin(angle) * radius))
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            return path
        case .cross:
            // Slim bars ending in pointed diamonds, each tipped with a bead,
            // and a pierced diamond where they cross.
            func diamond(_ cx: CGFloat, _ cy: CGFloat, _ size: CGFloat) -> Path {
                box(cx - size / 2, cy - size / 2, size, size, corner: 0.01).applying(
                    CGAffineTransform(translationX: pt(cx, cy).x, y: pt(cx, cy).y).rotated(by: .pi / 4)
                        .translatedBy(x: -pt(cx, cy).x, y: -pt(cx, cy).y))
            }
            var path = box(0.45, 0.1, 0.1, 0.8, corner: 0.01).union(box(0.16, 0.3, 0.68, 0.1, corner: 0.01))
            for (x, y, bx, by) in [(0.5, 0.12, 0.5, 0.03), (0.5, 0.88, 0.5, 0.97), (0.16, 0.35, 0.07, 0.35), (0.84, 0.35, 0.93, 0.35)] {
                path = path.union(diamond(x, y, 0.14)).union(ellipse(bx, by, 0.06, 0.06))
            }
            return path.union(diamond(0.5, 0.35, 0.22)).subtracting(ellipse(0.5, 0.35, 0.08, 0.08))
        case .wings:
            // One wing with a scalloped trailing edge, and its mirror.
            var wing = Path()
            wing.move(to: pt(0.47, 0.34))
            wing.addCurve(to: pt(0.02, 0.14), control1: pt(0.36, 0.14), control2: pt(0.14, 0.06))
            let tips: [(CGFloat, CGFloat)] = [(0.06, 0.34), (0.12, 0.5), (0.22, 0.64), (0.34, 0.74), (0.46, 0.7)]
            var previous = pt(0.02, 0.14)
            for tip in tips {
                let next = pt(tip.0, tip.1)
                let bulge = CGPoint(x: (previous.x + next.x) / 2 - 0.05 * side, y: (previous.y + next.y) / 2 + 0.04 * side)
                wing.addQuadCurve(to: next, control: bulge)
                previous = next
            }
            wing.addCurve(to: pt(0.47, 0.34), control1: pt(0.5, 0.6), control2: pt(0.5, 0.44))
            wing.closeSubpath()
            return wing.union(wing.applying(mirror))
        case .butterfly:
            // A pointed forewing and a rounded hindwing, mirrored, on a slim body.
            var fore = Path()
            fore.move(to: pt(0.47, 0.42))
            fore.addCurve(to: pt(0.06, 0.14), control1: pt(0.38, 0.2), control2: pt(0.16, 0.08))
            fore.addCurve(to: pt(0.47, 0.52), control1: pt(0.02, 0.42), control2: pt(0.3, 0.56))
            fore.closeSubpath()
            var hind = Path()
            hind.move(to: pt(0.47, 0.5))
            hind.addCurve(to: pt(0.26, 0.86), control1: pt(0.2, 0.52), control2: pt(0.12, 0.78))
            hind.addCurve(to: pt(0.48, 0.58), control1: pt(0.4, 0.94), control2: pt(0.48, 0.74))
            hind.closeSubpath()
            var path = fore.union(hind)
            path = path.union(path.applying(mirror))
            path = path.union(box(0.475, 0.3, 0.05, 0.46, corner: 0.025))
            let feeler = box(0.492, 0.1, 0.016, 0.22, corner: 0.008)
            let tilt = CGAffineTransform(translationX: pt(0.5, 0.32).x, y: pt(0.5, 0.32).y).rotated(by: -0.35)
                .translatedBy(x: -pt(0.5, 0.32).x, y: -pt(0.5, 0.32).y)
            let left = feeler.applying(tilt)
            return path.union(left).union(left.applying(mirror))
        case .moon:
            return ellipse(0.5, 0.5, 0.82, 0.82).subtracting(ellipse(0.68, 0.4, 0.66, 0.66))
        case .bow:
            var loops = ellipse(0.28, 0.4, 0.44, 0.3, degrees: -18)
            loops = loops.union(box(0.34, 0.5, 0.1, 0.36, corner: 0.03).applying(
                CGAffineTransform(translationX: pt(0.39, 0.5).x, y: pt(0.39, 0.5).y).rotated(by: 0.35)
                    .translatedBy(x: -pt(0.39, 0.5).x, y: -pt(0.39, 0.5).y)))
            loops = loops.union(loops.applying(mirror))
            return loops.union(ellipse(0.5, 0.44, 0.18, 0.18))
        }
    }
}

// MARK: Label

struct LabelWidget: View {
    let instance: WidgetInstance

    var body: some View {
        let options = instance.options
        let ink = options.ink.map { Color($0) } ?? Color(hex: 0x1A1714)
        let name = options.customText.isEmpty ? "MIDNIGHT" : options.customText
        let small = instance.size == .small
        ZStack {
            Color(instance.tint)
            // A faint sheen, like light on glass.
            LinearGradient(colors: [.white.opacity(0.12), .clear, .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RoundedRectangle(cornerRadius: 6).strokeBorder(ink.opacity(0.7), lineWidth: 1).padding(small ? 9 : 11)
            RoundedRectangle(cornerRadius: 4).strokeBorder(ink.opacity(0.35), lineWidth: 0.6).padding(small ? 13 : 15)
            VStack(spacing: small ? 6 : 8) {
                ornament(ink)
                Text(name)
                    .textStyle(.luxe, size: small ? 28 : 40)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text(options.caption.isEmpty ? "EAU DE PARFUM" : options.caption)
                    .font(.system(size: small ? 8 : 10, weight: .medium, design: .serif))
                    .tracking(small ? 2 : 3)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                ornament(ink)
            }
            .foregroundStyle(ink)
            .padding(.horizontal, small ? 20 : 30)
            if !small {
                Text("100 ML · 3.4 FL OZ")
                    .font(.system(size: 8, weight: .medium, design: .serif))
                    .tracking(1.5)
                    .foregroundStyle(ink.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(22)
            }
        }
    }

    private func ornament(_ ink: Color) -> some View {
        HStack(spacing: 6) {
            Rectangle().frame(width: 22, height: 0.6)
            Image(systemName: "sparkle").font(.system(size: 7))
            Rectangle().frame(width: 22, height: 0.6)
        }
        .foregroundStyle(ink.opacity(0.75))
    }
}

// MARK: Aura

struct AuraWidget: View {
    let instance: WidgetInstance

    var body: some View {
        WidgetTimeline(.everyMinute) { context in
            let reading = AuraReading.reading(for: context.date)
            let colors = reading.colors.map { Color(hex: $0) }
            ZStack {
                Color(instance.tint)
                AuraField(colors: colors)
                VStack(spacing: 4) {
                    Text("today\u{2019}s aura")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .opacity(0.75)
                    Text(reading.name)
                        .font(.system(size: instance.size == .small ? 26 : 34, weight: .regular, design: .serif).italic())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if instance.size != .small {
                        Text(reading.meaning)
                            .font(.system(size: 12, weight: .medium))
                            .opacity(0.8)
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 6)
                .padding(14)
            }
        }
    }
}

/// Soft pools of color drifting past each other.
struct AuraField: View {
    let colors: [Color]
    @Environment(\.widgetSnapshot) private var snapshot
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if snapshot {
            GeometryReader { geometry in
                let side = max(geometry.size.width, geometry.size.height)
                ZStack {
                    ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                        RadialGradient(colors: [color.opacity(0.95), color.opacity(0.4), .clear], center: .center,
                                       startRadius: 0, endRadius: side * 0.55)
                            .frame(width: side * 1.1, height: side * 1.1)
                            .position(AuraLayer.AuraView.anchor(index, in: geometry.size))
                    }
                }
            }
        } else {
            AuraLayer(colors: colors.map { NSColor($0).cgColor }, isRunning: isVisible && !reduceMotion)
        }
    }
}

struct AuraLayer: NSViewRepresentable {
    let colors: [CGColor]
    let isRunning: Bool

    func makeNSView(context: Context) -> AuraView { AuraView() }

    func updateNSView(_ view: AuraView, context: Context) {
        view.configure(colors: colors)
        view.isRunning = isRunning
    }

    final class AuraView: LiveLayerView {
        private var blobs: [CAGradientLayer] = []
        private var colors: [CGColor] = []
        private var size = CGSize.zero

        override init() {
            super.init()
            layer?.masksToBounds = true
            for _ in 0..<3 {
                let blob = CAGradientLayer()
                blob.type = .radial
                blob.startPoint = CGPoint(x: 0.5, y: 0.5)
                blob.endPoint = CGPoint(x: 1, y: 1)
                blob.locations = [0, 0.4, 1]
                root.addSublayer(blob)
                blobs.append(blob)
            }
        }

        required init?(coder: NSCoder) { nil }

        static func anchor(_ index: Int, in size: CGSize) -> CGPoint {
            let spots: [(CGFloat, CGFloat)] = [(0.25, 0.3), (0.78, 0.36), (0.5, 0.82)]
            let spot = spots[index % spots.count]
            return CGPoint(x: size.width * spot.0, y: size.height * spot.1)
        }

        func configure(colors: [CGColor]) {
            guard colors != self.colors else { return }
            self.colors = colors
            CATransaction.begin()
            CATransaction.setAnimationDuration(1.2)
            for (index, blob) in blobs.enumerated() where !colors.isEmpty {
                let color = colors[index % colors.count]
                blob.colors = [color.copy(alpha: 0.95), color.copy(alpha: 0.4), color.copy(alpha: 0)].compactMap { $0 }
            }
            CATransaction.commit()
        }

        override func build(in bounds: CGRect) {
            size = bounds.size
            let side = max(bounds.width, bounds.height) * 1.1
            for (index, blob) in blobs.enumerated() {
                blob.bounds = CGRect(x: 0, y: 0, width: side, height: side)
                blob.position = Self.anchor(index, in: bounds.size)
            }
        }

        override func refresh() {
            for (index, blob) in blobs.enumerated() {
                blob.removeAllAnimations()
                guard isRunning else { continue }
                let home = Self.anchor(index, in: size)
                let reach = CGSize(width: size.width * 0.18, height: size.height * 0.16)
                let drift = CAKeyframeAnimation(keyPath: "position")
                drift.values = [(0, 0), (1, -0.6), (0.2, 1), (-0.9, 0.4), (0, 0)].map { dx, dy in
                    NSValue(point: CGPoint(x: home.x + dx * reach.width * (index == 1 ? -1 : 1), y: home.y + dy * reach.height))
                }
                drift.duration = 12 + Double(index) * 3.5
                drift.calculationMode = .cubic
                drift.repeatCount = .infinity
                drift.isRemovedOnCompletion = false
                drift.preferredFrameRateRange = Self.rate(20)
                blob.add(drift, forKey: "drift")
                blob.add(Self.loop("transform.scale", from: 0.9, to: 1.12, duration: 5 + Double(index) * 1.3, fps: 20), forKey: "swell")
            }
        }
    }
}

// MARK: Tarot
