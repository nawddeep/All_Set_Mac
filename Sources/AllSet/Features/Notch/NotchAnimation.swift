import SwiftUI

/// Motion for the notch. Every change to its shape goes through one of these
/// explicitly, so opening and closing can move differently. With Reduce
/// Motion on they become a short dissolve, like the rest of the app (`Motion`).
enum NotchAnimation {
    /// Opening: quick, with a hint of overshoot like the iPhone's island.
    static var open: Animation { Motion.resolved(.spring(duration: 0.5, bounce: 0.18)) }
    /// Closing: quick, with the smallest settle as it tucks back into the notch.
    static var close: Animation { Motion.resolved(.spring(duration: 0.4, bounce: 0.12)) }
    /// Live activities growing out of, or back into, the closed notch.
    static var activity: Animation { Motion.resolved(.spring(duration: 0.45, bounce: 0.22)) }
    /// The small swell while the pointer rests on the closed notch.
    static var hover: Animation { Motion.resolved(.spring(duration: 0.3, bounce: 0.25)) }
    static var tab: Animation { Motion.resolved(.spring(duration: 0.45, bounce: 0.08)) }

    /// Content fades in once the shape has started to grow, so it never shows
    /// squeezed into a half-open notch...
    static var contentIn: Animation { Motion.reducesMotion ? Motion.reduced : .smooth(duration: 0.3).delay(0.08) }
    /// ...and fades out before the shape has shrunk much.
    static var contentOut: Animation { Motion.resolved(.easeIn(duration: 0.18)) }
}

/// Content that fades in and settles into place as `progress` goes 0 → 1,
/// dropping a few points out of the notch as it grows. Opacity, scale and
/// offset only: the window server moves those without redrawing anything
/// (a blur would be redrawn, at full size, on every frame).
struct RevealEffect: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .scaleEffect(0.94 + 0.06 * progress, anchor: .top)
            .offset(y: -8 * (1 - progress))
    }
}

/// Content being tucked back into the notch: it shrinks toward the camera and
/// fades, rather than just vanishing, as `progress` goes 1 → 0.
struct RetractEffect: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .scaleEffect(0.84 + 0.16 * progress, anchor: .top)
            .offset(y: -14 * (1 - progress))
    }
}

/// A tab arriving from the side it lies on: from the right when moving right
/// along the tabs, from the left when moving left.
struct SlideEffect: ViewModifier {
    let progress: Double
    /// +1 comes from the right, -1 from the left.
    let side: Double

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .scaleEffect(0.97 + 0.03 * progress, anchor: .top)
            .offset(x: 22 * side * (1 - progress))
    }
}

extension AnyTransition {
    /// In: settles down out of the notch. Out: retracts up into it.
    static func reveal(in insertion: Animation = NotchAnimation.contentIn,
                       out removal: Animation = NotchAnimation.contentOut) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(active: RevealEffect(progress: 0), identity: RevealEffect(progress: 1)).animation(insertion),
            removal: .modifier(active: RetractEffect(progress: 0), identity: RetractEffect(progress: 1)).animation(removal))
    }

    /// Switching tabs: the new one slides in from its side, the old one out the other.
    static func tab(direction: Int) -> AnyTransition {
        let side = Double(direction.signum())
        return .asymmetric(
            insertion: .modifier(active: SlideEffect(progress: 0, side: side), identity: SlideEffect(progress: 1, side: side))
                .animation(NotchAnimation.contentIn),
            removal: .modifier(active: SlideEffect(progress: 0, side: -side), identity: SlideEffect(progress: 1, side: -side))
                .animation(NotchAnimation.contentOut))
    }
}
