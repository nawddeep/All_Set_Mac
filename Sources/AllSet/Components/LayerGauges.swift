import AppKit
import SwiftUI

// Gauges for numbers that change every second or two. Animated by SwiftUI,
// each change costs the app a redraw of the whole window on every frame of
// the glide; these hand the glide to Core Animation instead, which runs it
// outside the app, so a live gauge costs almost nothing between readings.

/// A ring filling clockwise from the top.
struct RingGaugeLayer: NSViewRepresentable {
    let fraction: Double
    let color: Color
    var track: Color?
    var lineWidth: CGFloat = 5

    func makeNSView(context: Context) -> RingGaugeView {
        let view = RingGaugeView()
        view.apply(self, animated: false)
        return view
    }

    func updateNSView(_ view: RingGaugeView, context: Context) {
        view.apply(self, animated: !context.transaction.disablesAnimations)
    }

    final class RingGaugeView: NSView {
        private let trackLayer = CAShapeLayer()
        private let fillLayer = CAShapeLayer()
        private var lineWidth: CGFloat = 5

        init() {
            super.init(frame: .zero)
            wantsLayer = true
            for shape in [trackLayer, fillLayer] {
                shape.fillColor = nil
                shape.lineCap = .round
                layer?.addSublayer(shape)
            }
            fillLayer.strokeEnd = 0
        }

        required init?(coder: NSCoder) { nil }

        func apply(_ gauge: RingGaugeLayer, animated: Bool) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            lineWidth = gauge.lineWidth
            trackLayer.lineWidth = gauge.lineWidth
            fillLayer.lineWidth = gauge.lineWidth
            fillLayer.strokeColor = NSColor(gauge.color).cgColor
            trackLayer.strokeColor = NSColor(gauge.track ?? gauge.color.opacity(0.18)).cgColor
            CATransaction.commit()

            let target = CGFloat(min(max(gauge.fraction, 0), 1))
            guard abs(fillLayer.strokeEnd - target) > 0.0005 else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(!animated)
            CATransaction.setAnimationDuration(0.6)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            fillLayer.strokeEnd = target
            CATransaction.commit()
        }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
            let path = CGMutablePath()
            // Layers here have y pointing up: start at the top, go clockwise.
            path.addArc(center: CGPoint(x: bounds.midX, y: bounds.midY), radius: max(radius, 0),
                        startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true)
            for shape in [trackLayer, fillLayer] {
                shape.frame = bounds
                shape.path = path
            }
            CATransaction.commit()
        }
    }
}

/// Bars side by side, each filling upward, or one bar filling to the right.
struct BarGaugeLayer: NSViewRepresentable {
    enum Direction {
        /// One column per value, filling up.
        case up
        /// One bar, filling right; uses the first value.
        case right
    }

    let values: [Double]
    let colors: [Color]
    var track: Color = .white.opacity(0.06)
    var direction: Direction = .up
    var spacing: CGFloat = 3
    var cornerRadius: CGFloat = 2
    /// Shortest a bar gets, so empty ones still show.
    var minimum: CGFloat = 2
    var duration = 0.4

    func makeNSView(context: Context) -> BarGaugeView {
        let view = BarGaugeView()
        view.gauge = self
        return view
    }

    func updateNSView(_ view: BarGaugeView, context: Context) {
        view.animated = !context.transaction.disablesAnimations
        view.gauge = self
    }

    final class BarGaugeView: NSView {
        private var tracks: [CALayer] = []
        private var fills: [CALayer] = []
        var animated = false
        var gauge: BarGaugeLayer? {
            didSet { needsLayout = true }
        }

        init() {
            super.init(frame: .zero)
            wantsLayer = true
        }

        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            guard let gauge, let root = layer else { return }
            let count = gauge.direction == .right ? min(gauge.values.count, 1) : gauge.values.count
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            while tracks.count < count {
                let track = CALayer()
                let fill = CALayer()
                root.addSublayer(track)
                root.addSublayer(fill)
                tracks.append(track)
                fills.append(fill)
            }
            while tracks.count > count {
                tracks.removeLast().removeFromSuperlayer()
                fills.removeLast().removeFromSuperlayer()
            }
            CATransaction.commit()

            let slots: [CGRect]
            switch gauge.direction {
            case .up:
                let width = count > 0 ? (bounds.width - gauge.spacing * CGFloat(count - 1)) / CGFloat(count) : 0
                slots = (0..<count).map { CGRect(x: CGFloat($0) * (width + gauge.spacing), y: 0, width: max(width, 0), height: bounds.height) }
            case .right:
                slots = count > 0 ? [bounds] : []
            }
            for index in 0..<count {
                let slot = slots[index]
                let value = CGFloat(min(max(gauge.values[index], 0), 1))
                let fillFrame: CGRect
                switch gauge.direction {
                case .up:
                    fillFrame = CGRect(x: slot.minX, y: slot.minY, width: slot.width,
                                       height: max(slot.height * value, gauge.minimum))
                case .right:
                    // Never narrower than it is tall, so a low value is a dot, not a sliver.
                    fillFrame = CGRect(x: slot.minX, y: slot.minY, width: max(slot.width * value, slot.height), height: slot.height)
                }
                let color = gauge.colors.isEmpty ? Color.white : gauge.colors[min(index, gauge.colors.count - 1)]
                let radius = gauge.direction == .right ? slot.height / 2 : gauge.cornerRadius

                CATransaction.begin()
                CATransaction.setDisableActions(true)
                tracks[index].frame = slot
                tracks[index].cornerRadius = radius
                tracks[index].backgroundColor = NSColor(gauge.track).cgColor
                fills[index].cornerRadius = radius
                fills[index].backgroundColor = NSColor(color).cgColor
                fills[index].opacity = gauge.direction == .right && value <= 0 ? 0 : 1
                CATransaction.commit()

                // A new bar appears at its value; a changed one glides there.
                let isNew = fills[index].frame == .zero
                CATransaction.begin()
                CATransaction.setDisableActions(!animated || isNew)
                CATransaction.setAnimationDuration(gauge.duration)
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
                fills[index].frame = fillFrame
                CATransaction.commit()
            }
        }
    }
}

// MARK: Snapshot stand-ins

extension EnvironmentValues {
    /// True while a widget is drawn into a picture (theme previews): views
    /// backed by AppKit or Core Animation can't draw there, so they stand in
    /// with plain SwiftUI drawings of the same thing.
    @Entry var widgetSnapshot = false
}

/// A ring filling clockwise from the top, run by Core Animation.
struct RingGauge: View {
    let fraction: Double
    let color: Color
    var track: Color?
    var lineWidth: CGFloat = 5
    @Environment(\.widgetSnapshot) private var snapshot

    var body: some View {
        if snapshot {
            ZStack {
                Circle().stroke(track ?? color.opacity(0.2), lineWidth: lineWidth)
                Circle().trim(from: 0, to: min(max(fraction, 0), 1))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(lineWidth / 2)
        } else {
            RingGaugeLayer(fraction: fraction, color: color, track: track, lineWidth: lineWidth)
        }
    }
}

/// Bars filling up, or one bar filling right, run by Core Animation.
struct BarGauge: View {
    typealias Direction = BarGaugeLayer.Direction

    let values: [Double]
    let colors: [Color]
    var track: Color = .white.opacity(0.06)
    var direction: Direction = .up
    var spacing: CGFloat = 3
    var cornerRadius: CGFloat = 2
    var minimum: CGFloat = 2
    var duration = 0.4
    @Environment(\.widgetSnapshot) private var snapshot

    var body: some View {
        if snapshot {
            Canvas { context, size in
                let color = { (index: Int) in colors.isEmpty ? Color.accentColor : colors[index % colors.count] }
                if direction == .right {
                    let bar = CGRect(origin: .zero, size: size)
                    context.fill(Path(roundedRect: bar, cornerRadius: cornerRadius), with: .color(track))
                    let fill = CGRect(x: 0, y: 0, width: max(size.width * CGFloat(min(max(values.first ?? 0, 0), 1)), minimum), height: size.height)
                    context.fill(Path(roundedRect: fill, cornerRadius: cornerRadius), with: .color(color(0)))
                } else if !values.isEmpty {
                    let width = (size.width - spacing * CGFloat(values.count - 1)) / CGFloat(values.count)
                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) * (width + spacing)
                        context.fill(Path(roundedRect: CGRect(x: x, y: 0, width: width, height: size.height), cornerRadius: cornerRadius), with: .color(track))
                        let height = max(size.height * CGFloat(min(max(value, 0), 1)), minimum)
                        context.fill(Path(roundedRect: CGRect(x: x, y: size.height - height, width: width, height: height), cornerRadius: cornerRadius),
                                     with: .color(color(index)))
                    }
                }
            }
        } else {
            BarGaugeLayer(values: values, colors: colors, track: track, direction: direction, spacing: spacing,
                          cornerRadius: cornerRadius, minimum: minimum, duration: duration)
        }
    }
}
