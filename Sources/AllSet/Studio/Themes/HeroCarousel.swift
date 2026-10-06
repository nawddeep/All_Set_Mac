import AllSetCore
import AppKit
import SwiftUI

/// How the Themes page moves right now, from the app's performance policy.
/// Reduce Motion swaps slides for short fades and flattens the carousel; Low
/// Power Mode or a hot Mac drops what is only there to look good.
struct ThemesMotion: Equatable {
    /// Reduce Motion is on.
    let reduced: Bool
    /// Low Power Mode, or the Mac is hot.
    let saving: Bool

    init(_ policy: PerformancePolicy) {
        reduced = policy.reducesMotion
        saving = policy.tier >= .saver
    }

    /// The carousel landing on a card: soft and settled, no overshoot.
    var snap: Animation { reduced ? Motion.reduced : .smooth(duration: saving ? 0.35 : 0.45) }
    /// The panel's atmosphere changing theme.
    var backdrop: Animation { reduced || saving ? Motion.reduced : .easeInOut(duration: 0.7) }
    /// Words, badges and buttons appearing: a fade either way.
    var fade: Animation { reduced ? Motion.reduced : .easeInOut(duration: 0.18) }
    /// Whether a card may rise (grow, cast a shadow) under the pointer.
    var lifts: Bool { !reduced && !saving }
    /// Whether the selected card glows in its theme's color.
    var glows: Bool { !saving }
}

/// The Themes hero: a row of cards with the chosen one large in the middle,
/// going round: past the last theme comes the first again, so the selected
/// card always has neighbours on both sides.
///
/// One continuous `position` (in cards, 2.3 = a third of the way from card 2
/// to card 3; it keeps counting past the end, 9 being card 1 again of 8)
/// drives every card's scale, shade, offset and tilt, so a drag, a swipe and
/// a key press all animate the same way and land on a card.
struct HeroCarousel: View {
    let items: [ThemeSet]
    let services: AppServices
    /// The theme at the center, for the parts of the page that follow it.
    @Binding var selection: Int
    let layout: ThemeCarouselLayout
    /// Room kept from the panel's edges for the arrows.
    let margin: CGFloat

    @State private var position: CGFloat = 0
    @State private var dragStart: CGFloat?
    @State private var swipeStart: CGFloat?
    /// Goes up when the row should dissolve to its new arrangement rather
    /// than slide there (Reduce Motion).
    @State private var dissolve = 0
    /// Where the row is sliding from, so the cards it's leaving stay in it
    /// until they're out of sight, and which slide that was.
    @State private var leaving: (slot: Int, slide: Int)?
    @State private var slides = 0
    @FocusState private var focused: Bool

    private var motion: ThemesMotion { ThemesMotion(services.ui.performance) }
    /// Neighbours a side: two, or fewer when there aren't that many
    /// different themes to put there.
    private var reach: Int { min(ThemeCarouselLayout.reach, max((items.count - 1) / 2, 0)) }
    /// The slot at the center. Slots count on past the ends of `items`.
    private var center: Int { Int(position.rounded()) }

    private func item(at slot: Int) -> Int {
        let count = max(items.count, 1)
        return ((slot % count) + count) % count
    }

    private func go(to slot: Int) {
        guard items.count > 1, CGFloat(slot) != position || item(at: slot) != selection else { return }
        let motion = self.motion
        slides += 1
        let slide = slides
        leaving = (center, slide)
        withAnimation(motion.snap) {
            selection = item(at: slot)
            position = CGFloat(slot)
            if motion.reduced { dissolve += 1 }
        } completion: {
            if leaving?.slide == slide { leaving = nil }
        }
    }

    /// Lands near where a drag or swipe was heading, at most two cards from
    /// where it began.
    private func land(from start: CGFloat, heading projected: CGFloat) {
        go(to: Int(min(max(projected, start - 2), start + 2).rounded()))
    }

    var body: some View {
        let motion = self.motion
        ZStack {
            cards(motion)
                .id(dissolve)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(drag)
        .overlay(alignment: .leading) { arrow("chevron.left", by: -1).padding(.leading, margin) }
        .overlay(alignment: .trailing) { arrow("chevron.right", by: 1).padding(.trailing, margin) }
        // On top, but only scrolling stops at it: clicks and drags pass through.
        .overlay(CarouselScrollCatcher { scrolled($0) })
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(.leftArrow) { go(to: center - 1); return .handled }
        .onKeyPress(.rightArrow) { go(to: center + 1); return .handled }
        .onChange(of: center) { _, slot in selection = item(at: slot) }
        // Set from outside (the page choosing a theme): go to the nearest
        // place in the row that shows it.
        .onChange(of: selection) { _, chosen in
            guard !items.isEmpty, item(at: center) != chosen else { return }
            let ahead = (chosen - item(at: center) + items.count) % items.count
            go(to: center + (ahead <= items.count / 2 ? ahead : ahead - items.count))
        }
        .onAppear {
            position = CGFloat(min(max(selection, 0), max(items.count - 1, 0)))
        }
    }

    /// The selected card and its neighbours, plus, while the row slides,
    /// the ones it is sliding away from.
    private func cards(_ motion: ThemesMotion) -> some View {
        let center = self.center, reach = self.reach
        let from = leaving?.slot ?? center
        return ZStack {
            if !items.isEmpty {
                ForEach((min(center, from) - reach)...(max(center, from) + reach), id: \.self) { slot in
                    let set = items[item(at: slot)]
                    ThemePreviewCard(set: set, services: services, isSelected: slot == center,
                                     isCompact: layout.cardSize.height < 230)
                        .modifier(CarouselCardEffect(position: position, slot: slot, layout: layout, reach: self.reach,
                                                     glow: motion.glows ? Color(services.lighting(of: set).primary) : nil,
                                                     flat: motion.reduced))
                        // Strictly by distance: nearer the center, nearer the front.
                        .zIndex(Double(100 - abs(slot - center)))
                        .onTapGesture {
                            focused = true
                            if slot == center { services.ui.page = .themeSet(set.id) } else { go(to: slot) }
                        }
                }
            }
        }
    }

    private func arrow(_ symbol: String, by step: Int) -> some View {
        Button { focused = true; go(to: center + step) } label: { Image(systemName: symbol).foregroundStyle(DS.Ink.primary) }
            .buttonStyle(FloatingButtonStyle(diameter: 36))
            .opacity(items.count > 1 ? 1 : 0)
            .accessibilityLabel(step < 0 ? "Previous theme" : "Next theme")
    }

    // MARK: Input

    /// Follows the pointer, then lands on the card it was heading for.
    private var drag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragStart == nil { dragStart = position }
                position = (dragStart ?? position) - value.translation.width / layout.step(flat: motion.reduced)
            }
            .onEnded { value in
                let start = dragStart ?? position
                dragStart = nil
                land(from: start, heading: start - value.predictedEndTranslation.width / layout.step(flat: motion.reduced))
            }
    }

    private func scrolled(_ input: CarouselScrollCatcher.Input) {
        switch input {
        case .moved(let dx):
            if swipeStart == nil { swipeStart = position }
            position -= dx / layout.step(flat: motion.reduced)
        case .released(let velocity):
            let start = swipeStart ?? position
            swipeStart = nil
            // A flick carries on a little, as a drag does: about a fifth of a second of it.
            land(from: start, heading: position - velocity * 12 / layout.step(flat: motion.reduced))
        case .stepped(let direction):
            go(to: center + direction)
        }
    }
}

/// A card's place in the row, worked out from its distance to the center.
/// Animatable, so a snap animates `position` and only this runs each frame,
/// not the carousel's body.
private struct CarouselCardEffect: ViewModifier, Animatable {
    var position: CGFloat
    let slot: Int
    let layout: ThemeCarouselLayout
    /// Neighbours a side that show.
    let reach: Int
    /// The theme's own color, around the card at the center; nil for no glow.
    let glow: Color?
    /// No rotation (Reduce Motion).
    let flat: Bool

    nonisolated var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }

    func body(content: Content) -> some View {
        let distance = CGFloat(slot) - position
        let depth = ThemeCarouselDepth(distance: distance, flat: flat, reach: reach)
        let size = layout.size(at: distance)
        content
            .frame(width: size.width, height: size.height)
            // Side cards are darkened, not see-through (see `ThemeCarouselDepth.dim`).
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                    .fill(Color.black.opacity(depth.dim))
                    .allowsHitTesting(false)
            }
            // Ready-made pictures behind the card: only their opacity changes
            // as the row moves, never a shadow or a blur. The selected card
            // stands on a deeper shadow and glows in its theme's color.
            .background {
                CardHalo(spread: .shadow).foregroundStyle(.black).opacity(0.3 + 0.25 * depth.glow).offset(y: 8)
                if let glow {
                    CardHalo(spread: .glow).foregroundStyle(glow).opacity(0.55 * depth.glow)
                }
            }
            .scaleEffect(depth.scale)
            .rotation3DEffect(.degrees(depth.tilt), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .offset(x: layout.offset(at: distance, flat: flat), y: depth.dip)
            .opacity(depth.opacity)
    }
}

/// Sideways scrolling over the carousel: a trackpad or Magic Mouse swipe
/// moves the row with the fingers and lands it when they lift; a wheel
/// steps a card a notch. Anything mostly vertical is passed on, so the page
/// still scrolls with the pointer over the hero. Clicks and drags never
/// stop here (the same hit-testing as the mixer's `ScrollWheelCatcher`).
struct CarouselScrollCatcher: NSViewRepresentable {
    enum Input {
        /// The fingers moved this far sideways, in points.
        case moved(CGFloat)
        /// They lifted, moving this many points a frame.
        case released(velocity: CGFloat)
        /// One notch of a wheel: 1 for the next card, -1 for the one before.
        case stepped(Int)
    }

    let onInput: (Input) -> Void

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        view.onInput = onInput
        return view
    }

    func updateNSView(_ view: CatcherView, context: Context) {
        view.onInput = onInput
    }

    final class CatcherView: NSView {
        private enum Owner { case carousel, page }

        var onInput: ((Input) -> Void)?
        /// Whose gesture this is, decided by its first movement and kept
        /// until the fingers lift and any glide ends: a swipe that drifts
        /// never scrolls the page as well.
        private var owner: Owner?
        /// The page saw this gesture start before its direction was known.
        private var pageSawStart = false
        private var velocity: CGFloat = 0

        override func hitTest(_ point: NSPoint) -> NSView? {
            NSApp.currentEvent?.type == .scrollWheel ? super.hitTest(point) : nil
        }

        override func scrollWheel(with event: NSEvent) {
            let dx = event.scrollingDeltaX, dy = event.scrollingDeltaY
            let phase = event.phase, glide = event.momentumPhase

            // A plain wheel has no gesture to follow.
            if phase.isEmpty, glide.isEmpty {
                if abs(dx) > abs(dy) {
                    onInput?(.stepped(dx < 0 ? 1 : -1))
                } else {
                    super.scrollWheel(with: event)
                }
                return
            }
            // The glide after the fingers lift: the carousel has already landed.
            if phase.isEmpty {
                if owner == .carousel {
                    if glide.contains(.ended) || glide.contains(.cancelled) { owner = nil }
                } else {
                    super.scrollWheel(with: event)
                }
                return
            }
            // Fingers resting, not yet moving. Not passed on: the page's
            // scroll view would take the whole gesture from here.
            if phase.contains(.mayBegin) {
                owner = nil
                pageSawStart = false
                return
            }
            if phase.contains(.began) {
                owner = nil
                pageSawStart = false
                velocity = 0
            }
            if owner == nil, dx != 0 || dy != 0 {
                owner = abs(dx) > abs(dy) ? .carousel : .page
            }
            switch owner {
            case .carousel:
                if phase.contains(.ended) || phase.contains(.cancelled) {
                    // Whoever saw a gesture start sees it end.
                    if pageSawStart { super.scrollWheel(with: event) }
                    onInput?(.released(velocity: velocity))
                } else if dx != 0 {
                    velocity = velocity == 0 ? dx : velocity * 0.5 + dx * 0.5
                    onInput?(.moved(dx))
                }
            case .page:
                super.scrollWheel(with: event)
            case nil:
                // Fingers down, direction not known yet.
                if phase.contains(.ended) || phase.contains(.cancelled) {
                    if pageSawStart { super.scrollWheel(with: event) }
                } else {
                    pageSawStart = true
                    super.scrollWheel(with: event)
                }
            }
        }
    }
}
