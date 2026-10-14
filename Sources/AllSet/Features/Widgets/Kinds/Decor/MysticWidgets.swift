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

private struct TurningSpiral: View {
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

private struct SpiralLayer: NSViewRepresentable {
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

private struct AuraLayer: NSViewRepresentable {
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

struct TarotWidget: View {
    let instance: WidgetInstance

    var body: some View {
        WidgetTimeline(.everyMinute) { context in
            let card = TarotCard.card(for: context.date)
            let gold = instance.options.accent.map { Color($0) } ?? Color(hex: 0xE8C15A)
            ZStack {
                Color(instance.tint)
                PulsingGlow(color: gold.opacity(0.6), period: 5, intensity: 0.5)
                Sparkles(color: gold, density: 0.6)
                switch instance.size {
                case .small:
                    TarotFace(card: card, gold: gold).padding(.vertical, 12)
                case .medium:
                    HStack(spacing: 18) {
                        TarotFace(card: card, gold: gold).padding(.vertical, 12)
                        reading(card, gold: gold)
                    }
                    .padding(.horizontal, 18)
                case .large, .extraLarge:
                    VStack(spacing: 12) {
                        TarotFace(card: card, gold: gold).padding(.top, 18)
                        reading(card, gold: gold).multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 18)
                    }
                }
            }
        }
    }

    private func reading(_ card: TarotCard, gold: Color) -> some View {
        VStack(alignment: instance.size == .medium ? .leading : .center, spacing: 6) {
            WidgetWord("card of the day")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(gold.opacity(0.8))
            Text(card.name)
                .textStyle(.elegant, size: 22)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(card.message)
                .font(.system(size: 12, weight: .regular, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: instance.size == .medium ? .leading : .center)
    }
}

/// The card itself: gold frame, numeral, picture and name.
private struct TarotFace: View {
    let card: TarotCard
    let gold: Color

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let width = min(geometry.size.width, height * 0.6)
            VStack(spacing: height * 0.04) {
                Text(card.numeral)
                    .font(.system(size: height * 0.07, weight: .medium, design: .serif))
                ZStack {
                    Circle().strokeBorder(gold.opacity(0.6), lineWidth: 0.8)
                    ForEach(0..<12, id: \.self) { ray in
                        Rectangle()
                            .fill(gold.opacity(0.45))
                            .frame(width: 0.8, height: width * 0.1)
                            .offset(y: -width * 0.36)
                            .rotationEffect(.degrees(Double(ray) * 30))
                    }
                    Image(systemName: card.symbol)
                        .font(.system(size: width * 0.26, weight: .light))
                }
                .frame(width: width * 0.62, height: width * 0.62)
                Text(card.name.uppercased())
                    .font(.system(size: height * 0.06, weight: .medium, design: .serif))
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 6)
            }
            .foregroundStyle(gold)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: width * 0.08, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x1C1526), Color(hex: 0x0B0810)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: width * 0.08, style: .continuous).strokeBorder(gold, lineWidth: 1.2))
            .overlay(RoundedRectangle(cornerRadius: width * 0.06, style: .continuous).strokeBorder(gold.opacity(0.4), lineWidth: 0.6)
                .padding(width * 0.05))
            .shadow(color: gold.opacity(0.35), radius: 10)
            .frame(width: geometry.size.width, height: height)
        }
    }
}

// MARK: Star sign

struct ZodiacWidget: View {
    let instance: WidgetInstance

    var body: some View {
        let sign = instance.options.zodiac
        let star = instance.options.accent.map { Color($0) } ?? Color(hex: 0xCFE3FF)
        ZStack {
            LinearGradient(colors: [Color(instance.tint).mix(Color(hex: 0x2A2F6B), 0.35), Color(instance.tint)],
                           startPoint: .top, endPoint: .bottom)
            StarDust(color: star)
            switch instance.size {
            case .small:
                VStack(spacing: 2) {
                    Constellation(sign: sign, color: star).padding(.horizontal, 18).padding(.top, 14)
                    Text("\(sign.glyph) \(sign.title)")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .padding(.bottom, 12)
                }
            case .medium:
                HStack(spacing: 10) {
                    Constellation(sign: sign, color: star).padding(16)
                    details(sign, star: star)
                }
                .padding(.trailing, 18)
            case .large, .extraLarge:
                VStack(spacing: 8) {
                    Constellation(sign: sign, color: star).padding(28)
                    details(sign, star: star).padding(.bottom, 20)
                }
            }
        }
        .foregroundStyle(.white)
    }

    private func details(_ sign: ZodiacSign, star: Color) -> some View {
        VStack(alignment: instance.size == .medium ? .leading : .center, spacing: 5) {
            Text(sign.glyph)
                .font(.system(size: 26))
                .foregroundStyle(star)
            Text(sign.title)
                .textStyle(.elegant, size: 26)
            Text("\(sign.dates) · \(sign.element)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
            Text(sign.traits)
                .font(.system(size: 11, weight: .regular, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.8))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: instance.size == .medium ? .leading : .center)
    }
}

/// Faint background stars, the same every time.
private struct StarDust: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            for index in 0..<Int(size.width * size.height / 700) {
                let x = size.width * LiveLayerView.random(index, 31)
                let y = size.height * LiveLayerView.random(index, 32)
                let r = 0.4 + 1.0 * LiveLayerView.random(index, 33)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(color.opacity(0.15 + 0.35 * LiveLayerView.random(index, 34))))
            }
        }
    }
}

/// A sign's stars joined by fine lines, each star twinkling on its own beat.
private struct Constellation: View {
    let sign: ZodiacSign
    let color: Color

    var body: some View {
        let figure = sign.constellation
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Path { path in
                    for (a, b) in figure.lines {
                        path.move(to: CGPoint(x: figure.stars[a].x * size.width, y: figure.stars[a].y * size.height))
                        path.addLine(to: CGPoint(x: figure.stars[b].x * size.width, y: figure.stars[b].y * size.height))
                    }
                }
                .stroke(color.opacity(0.45), style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [2, 3]))
                TwinklingStars(points: figure.stars, color: color)
            }
        }
    }
}

struct TwinklingStars: View {
    let points: [CGPoint]
    let color: Color
    @Environment(\.widgetSnapshot) private var snapshot
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if snapshot {
            GeometryReader { geometry in
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    Circle().fill(color)
                        .frame(width: TwinkleLayer.TwinkleView.radius(index) * 2, height: TwinkleLayer.TwinkleView.radius(index) * 2)
                        .shadow(color: color, radius: 4)
                        .position(x: point.x * geometry.size.width, y: point.y * geometry.size.height)
                }
            }
        } else {
            TwinkleLayer(points: points, color: NSColor(color).cgColor, isRunning: isVisible && !reduceMotion)
        }
    }
}

private struct TwinkleLayer: NSViewRepresentable {
    let points: [CGPoint]
    let color: CGColor
    let isRunning: Bool

    func makeNSView(context: Context) -> TwinkleView { TwinkleView() }

    func updateNSView(_ view: TwinkleView, context: Context) {
        view.configure(points: points, color: color)
        view.isRunning = isRunning
    }

    final class TwinkleView: LiveLayerView {
        private var stars: [CALayer] = []
        private var points: [CGPoint] = []
        private var color: CGColor?

        static func radius(_ index: Int) -> CGFloat { 1.8 + 1.6 * CGFloat(LiveLayerView.random(index, 41)) }

        func configure(points: [CGPoint], color: CGColor) {
            guard points != self.points || color != self.color else { return }
            self.points = points
            self.color = color
            rebuild()
        }

        override func build(in bounds: CGRect) {
            stars.forEach { $0.removeFromSuperlayer() }
            stars = points.enumerated().map { index, point in
                let r = Self.radius(index)
                let star = CALayer()
                star.frame = CGRect(x: point.x * bounds.width - r, y: point.y * bounds.height - r, width: r * 2, height: r * 2)
                star.cornerRadius = r
                star.backgroundColor = color
                star.shadowColor = color
                star.shadowOpacity = 1
                star.shadowRadius = 4
                star.shadowOffset = .zero
                star.shadowPath = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: r * 2, height: r * 2), transform: nil)
                root.addSublayer(star)
                return star
            }
        }

        override func refresh() {
            for (index, star) in stars.enumerated() {
                star.removeAllAnimations()
                guard isRunning else { continue }
                star.add(Self.loop("opacity", from: 0.3, to: 1, duration: 1.2 + 1.8 * Self.random(index, 42),
                                   offset: 3 * Self.random(index, 43), fps: 10), forKey: "twinkle")
            }
        }
    }
}

// MARK: Magic ball

struct EightBallWidget: View {
    let instance: WidgetInstance
    @State private var answer: String?
    @State private var shakes = 0

    var body: some View {
        let window = instance.options.accent.map { Color($0) } ?? Color(hex: 0x3D5AFE)
        ZStack {
            Color(instance.tint)
            PulsingGlow(color: window.opacity(0.5), period: 4, intensity: 0.45)
            if instance.size == .medium {
                HStack(spacing: 20) {
                    ball(window).padding(14)
                    VStack(alignment: .leading, spacing: 6) {
                        WidgetWord("magic ball")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2)
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.55))
                        Text(answer ?? "Think of a question, then tap the ball")
                            .font(.system(size: answer == nil ? 14 : 20, weight: .medium, design: .serif))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .contentTransition(.opacity)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.trailing, 18)
            } else {
                ball(window).padding(16)
            }
        }
    }

    private func ball(_ window: Color) -> some View {
        Button {
            let next = MagicAnswers.all.filter { $0 != answer }.randomElement()
            withAnimation(.easeOut(duration: 0.15)) { answer = nil }
            shakes += 1
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(550))
                withAnimation(.spring(duration: 0.5, bounce: 0.3)) { answer = next }
            }
        } label: {
            GeometryReader { geometry in
                let side = min(geometry.size.width, geometry.size.height)
                ZStack {
                    Circle().fill(RadialGradient(colors: [Color(hex: 0x4A4A58), Color(hex: 0x111116), .black],
                                                 center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: side * 0.62))
                    Ellipse().fill(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom))
                        .frame(width: side * 0.5, height: side * 0.26)
                        .offset(x: -side * 0.12, y: -side * 0.3)
                    Circle()
                        .fill(RadialGradient(colors: [window.mix(.black, 0.55), .black], center: .center, startRadius: 0, endRadius: side * 0.24))
                        .overlay(Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1))
                        .frame(width: side * 0.46, height: side * 0.46)
                    if let answer {
                        ZStack {
                            Triangle().fill(window.opacity(0.9))
                            Text(answer)
                                .font(.system(size: side * 0.055, weight: .bold))
                                .textCase(.uppercase)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .frame(width: side * 0.22)
                                .minimumScaleFactor(0.5)
                                .offset(y: -side * 0.03)
                        }
                        .frame(width: side * 0.38, height: side * 0.33)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                    } else {
                        ZStack {
                            Circle().fill(.white).frame(width: side * 0.3, height: side * 0.3)
                            Text("8").font(.system(size: side * 0.2, weight: .heavy, design: .rounded)).foregroundStyle(.black)
                        }
                        .transition(.opacity)
                    }
                }
                .frame(width: side, height: side)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .keyframeAnimator(initialValue: 0.0, trigger: shakes) { content, angle in
                    content.rotationEffect(.degrees(angle)).offset(x: angle * 0.4)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-9, duration: 0.08)
                        CubicKeyframe(8, duration: 0.1)
                        CubicKeyframe(-6, duration: 0.1)
                        CubicKeyframe(4, duration: 0.1)
                        CubicKeyframe(0, duration: 0.12)
                    }
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Ask a question, then tap")
    }
}

/// A triangle pointing down, like the die in the window.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: Candle

struct CandleWidget: View {
    let instance: WidgetInstance

    var body: some View {
        let text = instance.options.customText
        ZStack {
            Color(instance.tint)
            switch instance.size {
            case .small:
                candle(height: 120).padding(.top, 10)
            case .medium:
                HStack(spacing: 22) {
                    candle(height: 128)
                    caption(text, size: 22).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 26)
            case .large, .extraLarge:
                VStack(spacing: 14) {
                    candle(height: 230)
                    caption(text, size: 26)
                }
                .padding(20)
            }
        }
    }

    private func caption(_ text: String, size: CGFloat) -> some View {
        Text(text.isEmpty ? "light a candle, make a wish" : text)
            .textStyle(.script, size: size)
            .foregroundStyle(Color(hex: 0xF6E7C8))
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .shadow(color: Color(hex: 0xFF9A3C).opacity(0.5), radius: 8)
    }

    /// A pillar candle with its flame, `height` tall in all.
    private func candle(height: CGFloat) -> some View {
        let width = height * 0.36
        let flame = CGSize(width: width * 0.42, height: width * 0.9)
        return VStack(spacing: 0) {
            FlickeringFlame()
                .frame(width: flame.width, height: flame.height)
            Rectangle().fill(Color(hex: 0x2A1E14)).frame(width: 1.6, height: height * 0.04)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xE9DCC2), Color(hex: 0xF7EEDC), Color(hex: 0xCDB894)],
                                         startPoint: .leading, endPoint: .trailing))
                // Warm light on the top, where the wax melts.
                Ellipse()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFE3A8), Color(hex: 0xEADBBE)], center: .center, startRadius: 0, endRadius: width * 0.5))
                    .frame(height: width * 0.22)
                    .offset(y: -width * 0.08)
                Capsule().fill(Color(hex: 0xF4EAD6)).frame(width: width * 0.09, height: width * 0.5)
                    .offset(x: -width * 0.28, y: width * 0.02)
                Capsule().fill(Color(hex: 0xF4EAD6)).frame(width: width * 0.07, height: width * 0.32)
                    .offset(x: width * 0.22, y: width * 0.02)
            }
            .frame(width: width, height: height - flame.height - height * 0.04)
        }
        .background(alignment: .top) {
            PulsingGlow(color: Color(hex: 0xFF9A3C), period: 2.6, intensity: 0.8)
                .frame(width: width * 3.4, height: width * 3.4)
                .offset(y: -width * 1.2)
                .allowsHitTesting(false)
        }
    }
}

/// A flame that sways and flickers.
struct FlickeringFlame: View {
    @Environment(\.widgetSnapshot) private var snapshot
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if snapshot {
            FlameShape().fill(LinearGradient(stops: FlameLayer.stops.map { .init(color: Color(nsColor: NSColor(cgColor: $0.0) ?? .orange), location: $0.1) },
                                             startPoint: .top, endPoint: .bottom))
        } else {
            FlameLayer(isRunning: isVisible && !reduceMotion)
        }
    }
}

struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path(FlameLayer.FlameView.teardrop(in: rect))
    }
}

private struct FlameLayer: NSViewRepresentable {
    let isRunning: Bool

    /// Colors from the tip down to the blue at the wick.
    static let stops: [(CGColor, Double)] = [
        (CGColor(red: 1, green: 0.42, blue: 0.05, alpha: 0.2), 0),
        (CGColor(red: 1, green: 0.62, blue: 0.2, alpha: 0.95), 0.3),
        (CGColor(red: 1, green: 0.93, blue: 0.7, alpha: 1), 0.72),
        (CGColor(red: 1, green: 0.98, blue: 0.9, alpha: 1), 0.86),
        (CGColor(red: 0.45, green: 0.6, blue: 1, alpha: 0.85), 1),
    ]

    func makeNSView(context: Context) -> FlameView { FlameView() }

    func updateNSView(_ view: FlameView, context: Context) {
        view.isRunning = isRunning
    }

    final class FlameView: LiveLayerView {
        private let flame = CAGradientLayer()
        private let outline = CAShapeLayer()

        nonisolated static func teardrop(in rect: CGRect) -> CGPath {
            let path = CGMutablePath()
            let w = rect.width, h = rect.height, x = rect.minX, y = rect.minY
            path.move(to: CGPoint(x: x + w / 2, y: y))
            path.addCurve(to: CGPoint(x: x + w, y: y + h * 0.68), control1: CGPoint(x: x + w * 0.62, y: y + h * 0.22),
                          control2: CGPoint(x: x + w, y: y + h * 0.42))
            path.addCurve(to: CGPoint(x: x + w / 2, y: y + h), control1: CGPoint(x: x + w, y: y + h * 0.9),
                          control2: CGPoint(x: x + w * 0.78, y: y + h))
            path.addCurve(to: CGPoint(x: x, y: y + h * 0.68), control1: CGPoint(x: x + w * 0.22, y: y + h),
                          control2: CGPoint(x: x, y: y + h * 0.9))
            path.addCurve(to: CGPoint(x: x + w / 2, y: y), control1: CGPoint(x: x, y: y + h * 0.42),
                          control2: CGPoint(x: x + w * 0.38, y: y + h * 0.22))
            path.closeSubpath()
            return path
        }

        override init() {
            super.init()
            flame.colors = FlameLayer.stops.map(\.0)
            flame.locations = FlameLayer.stops.map { NSNumber(value: $0.1) }
            flame.startPoint = CGPoint(x: 0.5, y: 0)
            flame.endPoint = CGPoint(x: 0.5, y: 1)
            flame.mask = outline
            // It sways from the wick.
            flame.anchorPoint = CGPoint(x: 0.5, y: 1)
            flame.shadowColor = CGColor(red: 1, green: 0.6, blue: 0.2, alpha: 1)
            flame.shadowOpacity = 0
            root.addSublayer(flame)
        }

        required init?(coder: NSCoder) { nil }

        override func build(in bounds: CGRect) {
            flame.bounds = bounds
            flame.position = CGPoint(x: bounds.midX, y: bounds.maxY)
            outline.frame = bounds
            outline.path = Self.teardrop(in: bounds)
        }

        override func refresh() {
            flame.removeAllAnimations()
            guard isRunning else { return }
            let flicker = CAKeyframeAnimation(keyPath: "transform")
            let steps: [(CGFloat, CGFloat, CGFloat)] = [(1, 1, 0), (0.94, 1.08, 2.5), (1.04, 0.94, -1.5), (0.97, 1.12, 3),
                                                        (1.02, 0.97, -3), (0.95, 1.05, 1), (1.03, 0.92, -2), (1, 1, 0)]
            flicker.values = steps.map { sx, sy, degrees in
                var transform = CATransform3DMakeRotation(degrees * .pi / 180, 0, 0, 1)
                transform = CATransform3DScale(transform, sx, sy, 1)
                return NSValue(caTransform3D: transform)
            }
            flicker.duration = 1.7
            flicker.calculationMode = .cubic
            flicker.repeatCount = .infinity
            flicker.isRemovedOnCompletion = false
            flicker.preferredFrameRateRange = Self.rate(24)
            flame.add(flicker, forKey: "flicker")
        }
    }
}
