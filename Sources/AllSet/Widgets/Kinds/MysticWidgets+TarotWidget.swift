import AllSetCore
import AppKit
import SwiftUI

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
struct TarotFace: View {
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
struct StarDust: View {
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
struct Constellation: View {
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

struct TwinkleLayer: NSViewRepresentable {
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
struct Triangle: Shape {
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
