import AllSetCore
import AppKit
import CoreImage
import SwiftUI

struct SparklesLayer: NSViewRepresentable {
    let color: CGColor
    let density: Double
    let isRunning: Bool

    func makeNSView(context: Context) -> SparkleView { SparkleView() }

    func updateNSView(_ view: SparkleView, context: Context) {
        view.configure(color: color, density: density)
        view.isRunning = isRunning
    }

    final class SparkleView: LiveLayerView {
        private let emitter = CAEmitterLayer()
        private let cell = CAEmitterCell()
        private var density = 1.2

        /// A soft four-point star, drawn once.
        private static let star: CGImage? = {
            let side = 64
            guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            let c = CGFloat(side) / 2
            let path = CGMutablePath()
            path.move(to: CGPoint(x: c, y: 0))
            path.addQuadCurve(to: CGPoint(x: CGFloat(side), y: c), control: CGPoint(x: c, y: c))
            path.addQuadCurve(to: CGPoint(x: c, y: CGFloat(side)), control: CGPoint(x: c, y: c))
            path.addQuadCurve(to: CGPoint(x: 0, y: c), control: CGPoint(x: c, y: c))
            path.addQuadCurve(to: CGPoint(x: c, y: 0), control: CGPoint(x: c, y: c))
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.addPath(path)
            context.fillPath()
            return context.makeImage()
        }()

        override init() {
            super.init()
            cell.contents = Self.star
            cell.lifetime = 1.6
            cell.lifetimeRange = 0.6
            cell.scale = 0.16
            cell.scaleRange = 0.1
            cell.scaleSpeed = -0.08
            cell.alphaSpeed = -0.55
            cell.spin = 1.2
            cell.spinRange = 1
            cell.velocity = 4
            cell.emissionRange = .pi * 2
            emitter.emitterCells = [cell]
            emitter.emitterShape = .rectangle
            emitter.emitterMode = .surface
            emitter.renderMode = .additive
            root.addSublayer(emitter)
        }

        required init?(coder: NSCoder) { nil }

        func configure(color: CGColor, density: Double) {
            cell.color = color
            emitter.emitterCells = [cell]
            if density != self.density {
                self.density = density
                refresh()
            }
        }

        override func build(in bounds: CGRect) {
            emitter.frame = bounds
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
            emitter.emitterSize = bounds.size
        }

        override func refresh() {
            let area = bounds.width * bounds.height / 10_000
            cell.birthRate = Float(max(area * density, 1))
            emitter.emitterCells = [cell]
            emitter.birthRate = isRunning ? 1 : 0
        }
    }
}
