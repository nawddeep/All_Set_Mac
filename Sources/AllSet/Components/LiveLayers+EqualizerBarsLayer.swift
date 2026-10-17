import AllSetCore
import AppKit
import CoreImage
import SwiftUI

struct EqualizerBarsLayer: NSViewRepresentable {
    let style: VisualizerStyle
    let colors: [CGColor]
    let count: Int
    let isPlaying: Bool
    let isRunning: Bool

    func makeNSView(context: Context) -> BarsView { BarsView() }

    func updateNSView(_ view: BarsView, context: Context) {
        view.configure(style: style, colors: colors, count: count, isPlaying: isPlaying)
        view.isRunning = isRunning
    }

    final class BarsView: LiveLayerView {
        private var bars: [CAGradientLayer] = []
        private var holders: [CALayer] = []
        private var style = VisualizerStyle.bars
        private var colors: [CGColor] = []
        private var count = 28
        private var isPlaying = false

        func configure(style: VisualizerStyle, colors: [CGColor], count: Int, isPlaying: Bool) {
            let shape = style != self.style || count != self.count
            let paint = colors != self.colors
            let play = isPlaying != self.isPlaying
            self.style = style
            self.colors = colors
            self.count = count
            self.isPlaying = isPlaying
            if shape {
                rebuild()
            } else {
                if paint {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    for bar in bars { bar.colors = colors }
                    CATransaction.commit()
                }
                if play { refresh() }
            }
        }

        /// Where each bar sits at rest: its frame, and for the ring its turn about the center.
        static func stillBars(style: VisualizerStyle, count: Int, size: CGSize,
                              _ emit: (CGRect, Double?, CGPoint?) -> Void) {
            let w = size.width, h = size.height
            switch style {
            case .bars, .mirror:
                let gap = w / Double(count) * 0.35
                let width = (w - gap * Double(count - 1)) / Double(count)
                for index in 0..<count {
                    let level = 0.25 + 0.6 * random(index, 3)
                    let height = h * 0.92 * level
                    let x = Double(index) * (width + gap)
                    let y = style == .bars ? h - height : (h - height) / 2
                    emit(CGRect(x: x, y: y, width: width, height: height), nil, nil)
                }
            case .ring:
                let center = CGPoint(x: w / 2, y: h / 2)
                let side = min(w, h)
                let inner = side * 0.26, length = side * 0.22
                let width = max(2 * .pi * inner / Double(count) * 0.55, 1.5)
                for index in 0..<count {
                    let level = 0.3 + 0.6 * random(index, 3)
                    let height = length * level
                    let rect = CGRect(x: center.x - width / 2, y: center.y - inner - height, width: width, height: height)
                    emit(rect, 2 * .pi * Double(index) / Double(count), center)
                }
            }
        }

        override func build(in bounds: CGRect) {
            holders.forEach { $0.removeFromSuperlayer() }
            holders.removeAll()
            bars.removeAll()
            let w = bounds.width, h = bounds.height
            for index in 0..<count {
                let holder = CALayer()
                holder.frame = bounds
                let bar = CAGradientLayer()
                bar.colors = colors
                // Flipped coordinates: the gradient runs from the bar's foot up.
                bar.startPoint = CGPoint(x: 0.5, y: 1)
                bar.endPoint = CGPoint(x: 0.5, y: 0)
                switch style {
                case .bars, .mirror:
                    let gap = w / Double(count) * 0.35
                    let width = (w - gap * Double(count - 1)) / Double(count)
                    let height = h * 0.92
                    bar.bounds = CGRect(x: 0, y: 0, width: width, height: height)
                    bar.cornerRadius = width / 2
                    let x = Double(index) * (width + gap) + width / 2
                    if style == .bars {
                        bar.anchorPoint = CGPoint(x: 0.5, y: 1)
                        bar.position = CGPoint(x: x, y: h)
                    } else {
                        bar.position = CGPoint(x: x, y: h / 2)
                    }
                case .ring:
                    let side = min(w, h)
                    let inner = side * 0.26, length = side * 0.22
                    let width = max(2 * .pi * inner / Double(count) * 0.55, 1.5)
                    bar.bounds = CGRect(x: 0, y: 0, width: width, height: length)
                    bar.cornerRadius = width / 2
                    bar.anchorPoint = CGPoint(x: 0.5, y: 1)
                    bar.position = CGPoint(x: w / 2, y: h / 2 - inner)
                    holder.setAffineTransform(CGAffineTransform(rotationAngle: 2 * .pi * Double(index) / Double(count)))
                }
                bar.transform = CATransform3DMakeScale(1, CGFloat(0.12 + 0.1 * Self.random(index, 5)), 1)
                holder.addSublayer(bar)
                root.addSublayer(holder)
                holders.append(holder)
                bars.append(bar)
            }
        }

        override func refresh() {
            for (index, bar) in bars.enumerated() {
                bar.removeAllAnimations()
                guard isRunning else { continue }
                let r1 = Self.random(index, 1), r2 = Self.random(index, 2), r3 = Self.random(index, 4)
                if isPlaying {
                    // Lows sway slowly and tall, highs flutter quick and short.
                    let position = Double(index) / Double(max(count - 1, 1))
                    let reach = style == .ring ? 1.0 : 1 - 0.35 * position
                    bar.add(Self.loop("transform.scale.y", from: 0.12 + 0.2 * r1, to: (0.55 + 0.45 * r2) * reach,
                                      duration: 0.22 + 0.45 * r3, offset: r1 * 2, fps: 30), forKey: "dance")
                } else {
                    bar.add(Self.loop("transform.scale.y", from: 0.08 + 0.06 * r1, to: 0.16 + 0.1 * r2,
                                      duration: 1.4 + 1.2 * r3, offset: r1 * 3, fps: 12), forKey: "breathe")
                }
            }
        }
    }
}

// MARK: Blinking light

/// A small round light: a REC dot, a LIVE badge, a tally lamp.
struct BlinkingLight: View {
    let color: Color
    var period = 1.2
    /// A hard on/off blink; otherwise a soft pulse.
    var hard = true
    @Environment(\.widgetSnapshot) private var snapshot
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if snapshot {
            Circle().fill(color).shadow(color: color, radius: 3)
        } else {
            BlinkingLightLayer(color: NSColor(color).cgColor, period: period, hard: hard, isRunning: isVisible && !reduceMotion)
        }
    }
}

struct BlinkingLightLayer: NSViewRepresentable {
    let color: CGColor
    let period: Double
    let hard: Bool
    let isRunning: Bool

    func makeNSView(context: Context) -> LightView { LightView() }

    func updateNSView(_ view: LightView, context: Context) {
        view.configure(color: color, period: period, hard: hard)
        view.isRunning = isRunning
    }

    final class LightView: LiveLayerView {
        private let dot = CALayer()
        private var period = 1.2
        private var hard = true

        override init() {
            super.init()
            dot.shadowOffset = .zero
            dot.shadowRadius = 3
            dot.shadowOpacity = 1
            root.addSublayer(dot)
        }

        required init?(coder: NSCoder) { nil }

        func configure(color: CGColor, period: Double, hard: Bool) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            dot.backgroundColor = color
            dot.shadowColor = color
            CATransaction.commit()
            if period != self.period || hard != self.hard {
                self.period = period
                self.hard = hard
                refresh()
            }
        }

        override func build(in bounds: CGRect) {
            let side = min(bounds.width, bounds.height)
            dot.frame = CGRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
            dot.cornerRadius = side / 2
            // A known shape: the shadow is drawn once, not worked out each frame.
            dot.shadowPath = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: side, height: side), transform: nil)
        }

        override func refresh() {
            dot.removeAllAnimations()
            guard isRunning else { return }
            if hard {
                let blink = CAKeyframeAnimation(keyPath: "opacity")
                blink.values = [1, 1, 0.15, 0.15]
                blink.keyTimes = [0, 0.55, 0.6, 1]
                blink.duration = period
                blink.repeatCount = .infinity
                blink.isRemovedOnCompletion = false
                blink.preferredFrameRateRange = Self.rate(10)
                dot.add(blink, forKey: "blink")
            } else {
                dot.add(Self.loop("opacity", from: 0.35, to: 1, duration: period / 2), forKey: "pulse")
            }
        }
    }
}

// MARK: VHS tracking

/// A band of tape noise rolling down the picture, and the odd jolt sideways.
struct TrackingBand: View {
    @Environment(\.widgetSnapshot) private var snapshot
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if snapshot {
            GeometryReader { geometry in
                LinearGradient(colors: [.clear, .white.opacity(0.12), .white.opacity(0.2), .white.opacity(0.12), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: geometry.size.height * 0.12)
                    .offset(y: geometry.size.height * 0.7)
            }
        } else {
            TrackingBandLayer(isRunning: isVisible && !reduceMotion)
        }
    }
}

struct TrackingBandLayer: NSViewRepresentable {
    let isRunning: Bool

    func makeNSView(context: Context) -> BandView { BandView() }

    func updateNSView(_ view: BandView, context: Context) {
        view.isRunning = isRunning
    }

    final class BandView: LiveLayerView {
        private let band = CAGradientLayer()
        private let line = CALayer()

        override init() {
            super.init()
            band.colors = [0, 0.12, 0.22, 0.12, 0].map { NSColor(white: 1, alpha: $0).cgColor }
            line.backgroundColor = NSColor(white: 1, alpha: 0.35).cgColor
            root.addSublayer(band)
            root.addSublayer(line)
            root.masksToBounds = true
        }

        required init?(coder: NSCoder) { nil }

        override func build(in bounds: CGRect) {
            band.frame = CGRect(x: 0, y: bounds.height * 0.7, width: bounds.width, height: bounds.height * 0.12)
            line.frame = CGRect(x: 0, y: bounds.height * 0.3, width: bounds.width, height: 1)
        }

        override func refresh() {
            band.removeAllAnimations()
            line.removeAllAnimations()
            guard isRunning else { return }
            let h = bounds.height
            let roll = CABasicAnimation(keyPath: "position.y")
            roll.fromValue = -h * 0.1
            roll.toValue = h * 1.1
            roll.duration = 5.5
            let group = CAAnimationGroup()
            group.animations = [roll]
            group.duration = 9
            group.repeatCount = .infinity
            group.isRemovedOnCompletion = false
            group.preferredFrameRateRange = Self.rate(24)
            band.add(group, forKey: "roll")
            let jolt = CAKeyframeAnimation(keyPath: "position.y")
            jolt.values = [h * 0.3, h * 0.3, h * 0.62, h * 0.18, h * 0.3]
            jolt.keyTimes = [0, 0.8, 0.84, 0.9, 1]
            jolt.duration = 7
            jolt.repeatCount = .infinity
            jolt.isRemovedOnCompletion = false
            jolt.preferredFrameRateRange = Self.rate(24)
            line.add(jolt, forKey: "jolt")
            line.add(Self.loop("opacity", from: 0.1, to: 0.6, duration: 0.9), forKey: "flicker")
        }
    }
}

// MARK: Ball in play

/// A glowing ball passed between points (fractions of the view), round and round.
struct BallInPlay: View {
    let points: [CGPoint]
    var color: Color = .white
    @Environment(\.widgetSnapshot) private var snapshot
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if snapshot || points.isEmpty {
            GeometryReader { geometry in
                if let first = points.first {
                    Circle().fill(color).frame(width: 7, height: 7).shadow(color: color, radius: 5)
                        .position(x: first.x * geometry.size.width, y: first.y * geometry.size.height)
                }
            }
        } else {
            BallInPlayLayer(points: points, color: NSColor(color).cgColor, isRunning: isVisible && !reduceMotion)
        }
    }
}

struct BallInPlayLayer: NSViewRepresentable {
    let points: [CGPoint]
    let color: CGColor
    let isRunning: Bool

    func makeNSView(context: Context) -> BallView { BallView() }

    func updateNSView(_ view: BallView, context: Context) {
        view.configure(points: points, color: color)
        view.isRunning = isRunning
    }

    final class BallView: LiveLayerView {
        private let ball = CALayer()
        private let trail = CAShapeLayer()
        private var points: [CGPoint] = []

        override init() {
            super.init()
            ball.shadowOffset = .zero
            ball.shadowRadius = 5
            ball.shadowOpacity = 1
            trail.fillColor = nil
            trail.lineWidth = 1.2
            trail.lineDashPattern = [2, 4]
            trail.lineCap = .round
            root.addSublayer(trail)
            root.addSublayer(ball)
        }

        required init?(coder: NSCoder) { nil }

        func configure(points: [CGPoint], color: CGColor) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            ball.backgroundColor = color
            ball.shadowColor = color
            trail.strokeColor = color.copy(alpha: 0.35)
            CATransaction.commit()
            if points != self.points {
                self.points = points
                rebuild()
            }
        }

        private func place(_ point: CGPoint, in bounds: CGRect) -> CGPoint {
            CGPoint(x: point.x * bounds.width, y: point.y * bounds.height)
        }

        override func build(in bounds: CGRect) {
            ball.bounds = CGRect(x: 0, y: 0, width: 7, height: 7)
            ball.cornerRadius = 3.5
            ball.shadowPath = CGPath(ellipseIn: ball.bounds, transform: nil)
            ball.position = points.first.map { place($0, in: bounds) } ?? .zero
            trail.frame = bounds
            let path = CGMutablePath()
            for (index, point) in points.enumerated() {
                if index == 0 { path.move(to: place(point, in: bounds)) } else { path.addLine(to: place(point, in: bounds)) }
            }
            trail.path = path
        }

        override func refresh() {
            ball.removeAllAnimations()
            trail.removeAllAnimations()
            guard isRunning, points.count > 1 else { return }
            let bounds = root.bounds
            var values = points.map { NSValue(point: place($0, in: bounds)) }
            values.append(values[0])
            let pass = CAKeyframeAnimation(keyPath: "position")
            pass.values = values
            // Each pass, then a touch on the ball before the next.
            pass.calculationMode = .cubic
            pass.duration = Double(points.count) * 1.25
            pass.repeatCount = .infinity
            pass.isRemovedOnCompletion = false
            pass.preferredFrameRateRange = Self.rate(30)
            ball.add(pass, forKey: "pass")
            trail.add(Self.loop("lineDashPhase", from: 0, to: -12, duration: 0.8, autoreverses: false, timing: .linear, fps: 12), forKey: "march")
        }
    }
}

// MARK: Sparkles

/// Tiny four-point stars that wink in and out: glitter, for anything.
struct Sparkles: View {
    var color: Color = .white
    /// Stars a second, per 100×100 points.
    var density = 1.2
    @Environment(\.widgetSnapshot) private var snapshot
    @Environment(\.widgetIsVisible) private var isVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if snapshot {
            GeometryReader { geometry in
                ForEach(0..<9, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: 6 + 8 * LiveLayerView.random(index, 7)))
                        .foregroundStyle(color)
                        .shadow(color: color, radius: 3)
                        .position(x: geometry.size.width * LiveLayerView.random(index, 8),
                                  y: geometry.size.height * LiveLayerView.random(index, 9))
                }
            }
        } else {
            SparklesLayer(color: NSColor(color).cgColor, density: density, isRunning: isVisible && !reduceMotion)
        }
    }
}
