import AllSetCore
import AppKit
import SwiftUI

struct FlameLayer: NSViewRepresentable {
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
