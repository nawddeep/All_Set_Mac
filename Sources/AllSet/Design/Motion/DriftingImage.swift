import AppKit
import SwiftUI

/// A picture that moves slowly (turning, swelling, sliding) with the motion
/// run by Core Animation. SwiftUI animations, even simple repeating ones, cost
/// the app a little work on every frame; these cost it nothing once started,
/// which matters for things on screen all day, like widgets and wallpapers.
struct DriftingImage: NSViewRepresentable {
    enum Motion: Equatable {
        /// Holds still.
        case still
        /// Slides slowly from side to side, slightly zoomed in (a film pan).
        case pan
        /// Zooms gently in and out.
        case breathe
        /// Turns and swells, with a second picture fading over it, so colors
        /// seem to flow. For gradients.
        case flow
    }

    let image: CGImage?
    /// For `.flow`: a second picture to fade in and out on top.
    var overlay: CGImage?
    var motion: Motion
    /// Seconds for one full swing; smaller is faster.
    var period: Double = 20

    func makeNSView(context: Context) -> DriftView {
        DriftView()
    }

    func updateNSView(_ view: DriftView, context: Context) {
        view.update(image: image, overlay: overlay, motion: motion, period: period)
    }

    final class DriftView: NSView {
        private let base = CALayer()
        private let top = CALayer()
        private var motion = Motion.still
        private var period = 20.0
        /// The size the running animations were made for.
        private var animatedSize = CGSize.zero

        init() {
            super.init(frame: .zero)
            wantsLayer = true
            layer?.masksToBounds = true
            for sublayer in [base, top] {
                sublayer.contentsGravity = .resizeAspectFill
                sublayer.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
                layer?.addSublayer(sublayer)
            }
        }

        required init?(coder: NSCoder) { nil }

        func update(image: CGImage?, overlay: CGImage?, motion: Motion, period: Double) {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if (base.contents as AnyObject?) !== image {
                base.contents = image
            }
            if (top.contents as AnyObject?) !== overlay {
                top.contents = overlay
            }
            top.isHidden = overlay == nil || motion != .flow
            CATransaction.commit()
            let stopped = motion != .still && base.animationKeys()?.isEmpty != false
            if motion != self.motion || period != self.period || stopped {
                self.motion = motion
                self.period = period
                animatedSize = .zero
                needsLayout = true
            }
        }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            // Turning needs a square as wide as the diagonal, or corners show.
            let side = motion == .flow ? hypot(bounds.width, bounds.height) : max(bounds.width, bounds.height)
            let square = motion == .flow
            for sublayer in [base, top] {
                sublayer.bounds = square ? CGRect(x: 0, y: 0, width: side, height: side) : bounds
                sublayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
            }
            CATransaction.commit()
            // Only when something changed: restarting jumps back to the start.
            if bounds.size != animatedSize {
                animatedSize = bounds.size
                restartAnimations()
            }
        }

        private func restartAnimations() {
            base.removeAllAnimations()
            top.removeAllAnimations()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            base.transform = CATransform3DIdentity
            top.transform = CATransform3DIdentity
            CATransaction.commit()
            guard bounds.width > 0 else { return }
            func swing(_ keyPath: String, from: Any, to: Any, duration: Double, offset: Double = 0) -> CABasicAnimation {
                let animation = CABasicAnimation(keyPath: keyPath)
                animation.fromValue = from
                animation.toValue = to
                animation.duration = duration
                animation.autoreverses = true
                animation.repeatCount = .infinity
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animation.beginTime = CACurrentMediaTime() - offset
                // Keeps running after the window hides and comes back.
                animation.isRemovedOnCompletion = false
                // Slow drifts look the same at 20 frames a second, and a
                // full-screen layer composited 20 times a second instead of
                // 60 or 120 saves the window server most of its work.
                animation.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 20, preferred: 20)
                return animation
            }
            switch motion {
            case .still:
                break
            case .pan:
                let travel = bounds.width * 0.025
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                base.transform = CATransform3DMakeScale(1.1, 1.1, 1)
                CATransaction.commit()
                let center = CGPoint(x: bounds.midX, y: bounds.midY)
                base.add(swing("position", from: NSValue(point: CGPoint(x: center.x + travel, y: center.y - travel * 0.4)),
                               to: NSValue(point: CGPoint(x: center.x - travel, y: center.y + travel * 0.4)),
                               duration: period), forKey: "pan")
            case .breathe:
                base.add(swing("transform.scale", from: 1.02, to: 1.12, duration: period), forKey: "breathe")
            case .flow:
                base.add(swing("transform.rotation.z", from: -0.35, to: 0.35, duration: period), forKey: "turn")
                base.add(swing("transform.scale", from: 1.0, to: 1.18, duration: period * 0.63, offset: period * 0.2), forKey: "swell")
                top.add(swing("transform.rotation.z", from: 0.45, to: -0.3, duration: period * 1.3, offset: period * 0.4), forKey: "turn")
                top.add(swing("opacity", from: 0.0, to: 0.85, duration: period * 0.8), forKey: "fade")
            }
        }
    }
}

/// A picture turning steadily, like a record, run by Core Animation. Stopping
/// leaves it where it was; starting again carries on from there.
struct SpinningImageLayer: NSViewRepresentable {
    let image: CGImage?
    let isSpinning: Bool
    var secondsPerTurn = 1.8

    func makeNSView(context: Context) -> SpinView {
        SpinView()
    }

    func updateNSView(_ view: SpinView, context: Context) {
        view.update(image: image, spinning: isSpinning, secondsPerTurn: secondsPerTurn)
    }

    final class SpinView: NSView {
        private let disc = CALayer()
        private var spinning = false
        private var secondsPerTurn = 1.8

        init() {
            super.init(frame: .zero)
            wantsLayer = true
            disc.contentsGravity = .resizeAspect
            disc.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
            disc.speed = 0
            layer?.addSublayer(disc)
        }

        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            disc.bounds = bounds
            disc.position = CGPoint(x: bounds.midX, y: bounds.midY)
            CATransaction.commit()
            addTurningIfNeeded()
        }

        func update(image: CGImage?, spinning: Bool, secondsPerTurn: Double) {
            if (disc.contents as AnyObject?) !== image {
                disc.contents = image
            }
            if secondsPerTurn != self.secondsPerTurn {
                self.secondsPerTurn = secondsPerTurn
                disc.removeAnimation(forKey: "turn")
            }
            addTurningIfNeeded()
            guard spinning != self.spinning else { return }
            self.spinning = spinning
            if spinning {
                // Carry on from where it stopped.
                let pausedAt = disc.timeOffset
                disc.speed = 1
                disc.timeOffset = 0
                disc.beginTime = 0
                disc.beginTime = disc.convertTime(CACurrentMediaTime(), from: nil) - pausedAt
            } else {
                let now = disc.convertTime(CACurrentMediaTime(), from: nil)
                disc.speed = 0
                disc.timeOffset = now
            }
        }

        private func addTurningIfNeeded() {
            guard disc.animation(forKey: "turn") == nil else { return }
            let turn = CABasicAnimation(keyPath: "transform.rotation.z")
            turn.fromValue = 0
            // Layers here have y pointing up, so clockwise is negative.
            turn.toValue = -2 * Double.pi
            turn.duration = secondsPerTurn
            turn.repeatCount = .infinity
            turn.isRemovedOnCompletion = false
            turn.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
            disc.add(turn, forKey: "turn")
        }
    }
}

/// A picture turning steadily, like a record (still in snapshots).
struct SpinningImage: View {
    let image: CGImage?
    let isSpinning: Bool
    var secondsPerTurn = 1.8
    @Environment(\.widgetSnapshot) private var snapshot

    var body: some View {
        if snapshot {
            if let image { Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit) }
        } else {
            SpinningImageLayer(image: image, isSpinning: isSpinning, secondsPerTurn: secondsPerTurn)
        }
    }
}
