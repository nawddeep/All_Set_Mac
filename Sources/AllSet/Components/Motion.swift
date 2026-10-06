import AllSetCore
import AppKit
import SwiftUI

/// The app's motion vocabulary. Every animation outside the notch (which has
/// its own tuned set in `NotchAnimation`) uses one of these, so timing and
/// easing feel the same everywhere. With Reduce Motion on, each becomes a
/// short dissolve instead of a slide, scale or bounce.
enum Motion {
    /// Hover highlights, toggles and other small changes: quick and flat.
    static let quick = Animation.smooth(duration: 0.2)
    /// Content changing in place: a new page, a new value, a section opening.
    static let standard = Animation.smooth(duration: 0.3)
    /// Slow cross-fades: rotating quotes, photos, the weather changing.
    static let gentle = Animation.smooth(duration: 0.6)
    /// Things lifting under the pointer, or being picked.
    static let responsive = Animation.spring(response: 0.35, dampingFraction: 0.8)
    /// Buttons giving under a click.
    static let press = Animation.spring(response: 0.25, dampingFraction: 0.65)
    /// A playful settle, for confirmations and stickers.
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    /// What every motion becomes with Reduce Motion on.
    static let reduced = Animation.easeInOut(duration: 0.15)

    /// Whether the Mac asks for less motion. Read live, so changing the
    /// setting takes effect at the next animation.
    static var reducesMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// `animation`, or a dissolve when Reduce Motion is on.
    static func resolved(_ animation: Animation) -> Animation { reducesMotion ? reduced : animation }
}

/// `withAnimation`, through the motion vocabulary and Reduce Motion.
@MainActor
@discardableResult
func withMotion<Result>(_ animation: Animation, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(Motion.resolved(animation), body)
}

extension View {
    /// `.animation(_:value:)` that turns into a dissolve with Reduce Motion on.
    func motion<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    let animation: Animation?
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(animation.map { reduceMotion ? Motion.reduced : $0 }, value: value)
    }
}

extension MotionLanguage {
    /// How content changes in place in this theme: a new number, a new line.
    /// Nil for still themes. Reduce Motion turns any of them into a dissolve.
    var change: Animation? {
        let animation: Animation? = switch self {
        case .calm: .smooth(duration: 0.5)
        case .energetic: .snappy(duration: 0.2)
        case .still: nil
        case .playful: .spring(response: 0.4, dampingFraction: 0.62)
        case .orbital: .smooth(duration: 0.9)
        case .cinematic: .easeInOut(duration: 0.7)
        }
        return animation.map(Motion.resolved)
    }
}
