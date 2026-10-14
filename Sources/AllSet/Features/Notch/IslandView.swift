import AllSetCore
import AppKit
import SwiftUI

/// The island itself: its black body and shadow drawn by Core Animation, with
/// the SwiftUI content inside clipped by a matching mask. The shape's springs
/// run in the window server, so the island grows and shrinks at the display's
/// full rate even while the app is busy (building a tab full of charts, say).
/// SwiftUI would drive the same animation from the main thread, one frame at a
/// time, and stutter whenever that thread did.
@MainActor
final class IslandView: NSView {
    private let model: NotchViewModel
    private let body = CAShapeLayer()
    private let mask = CAShapeLayer()
    private let clip = FlippedView()
    private let hostingView: NSHostingView<NotchRootView>
    /// What the shape was last set to, to tell which spring a change needs.
    private var shown: State?

    private struct State: Equatable {
        var size: CGSize
        var top: CGFloat
        var bottom: CGFloat
        var isExpanded: Bool
        var isHovering: Bool
        var tab: NotchViewModel.Tab
    }

    init(model: NotchViewModel, root: NotchRootView) {
        self.model = model
        hostingView = FirstClickHostingView(rootView: root)
        super.init(frame: .zero)
        wantsLayer = true
        hostingView.sizingOptions = []
        body.fillColor = NSColor.black.cgColor
        body.shadowColor = NSColor.black.cgColor
        body.shadowRadius = 16
        body.shadowOffset = CGSize(width: 0, height: 8)
        body.shadowOpacity = 0
        for shape in [body, mask] {
            shape.actions = ["path": NSNull(), "shadowPath": NSNull(), "bounds": NSNull(), "position": NSNull()]
        }
        mask.fillColor = NSColor.black.cgColor
        layer?.addSublayer(body)
        clip.wantsLayer = true
        clip.layer?.mask = mask
        clip.addSubview(hostingView)
        addSubview(clip)
        watch()
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    private var laidOutSize = CGSize.zero

    override func layout() {
        super.layout()
        // Only a new size re-places the shape; a layout pass mid-spring must not snap it.
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        clip.frame = bounds
        hostingView.frame = clip.bounds
        body.frame = bounds
        mask.frame = clip.bounds
        CATransaction.commit()
        apply(animated: false)
    }

    private func watch() {
        // The model is held weakly: the watcher is stored in the model's own
        // observation registrar, so a strong reference would keep a
        // short-lived island (the warm-up's) alive forever.
        AllSet.observe({ [weak model] in
            model.map { State(size: $0.shapeSize, top: $0.topCornerRadius, bottom: $0.bottomCornerRadius,
                              isExpanded: $0.isExpanded, isHovering: $0.isHovering, tab: $0.tab) }
        }) { [weak self] _ in self?.apply(animated: true) }
    }

    private func current() -> State {
        State(size: model.shapeSize, top: model.topCornerRadius, bottom: model.bottomCornerRadius,
              isExpanded: model.isExpanded, isHovering: model.isHovering, tab: model.tab)
    }

    /// The shape at `state`, hanging from the top middle of the view.
    private func path(_ state: State) -> CGPath {
        let rect = CGRect(x: bounds.midX - state.size.width / 2, y: 0, width: state.size.width, height: state.size.height)
        return NotchShape(topCornerRadius: state.top, bottomCornerRadius: state.bottom).path(in: rect).cgPath
    }

    private func apply(animated: Bool) {
        guard bounds.width > 0 else { return }
        let next = current()
        guard animated, let previous = shown, previous != next else {
            if shown != next || !animated {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                let path = path(next)
                body.path = path
                body.shadowPath = path
                mask.path = path
                body.shadowOpacity = next.isExpanded ? 0.5 : 0
                CATransaction.commit()
                shown = next
            }
            return
        }
        shown = next
        let target = path(next)
        let spring = Self.motion(from: previous, to: next)
        for (layer, keyPath) in [(body, "path"), (body, "shadowPath"), (mask, "path")] {
            let from: CGPath? = switch keyPath {
            case "shadowPath": layer.presentation()?.shadowPath ?? layer.shadowPath
            default: layer.presentation()?.path ?? layer.path
            }
            layer.add(spring(keyPath, from, target), forKey: keyPath)
        }
        let opacity = CABasicAnimation(keyPath: "shadowOpacity")
        opacity.fromValue = body.presentation()?.shadowOpacity ?? body.shadowOpacity
        opacity.toValue = next.isExpanded ? 0.5 : 0
        opacity.duration = next.isExpanded ? 0.35 : 0.2
        body.add(opacity, forKey: "shadowOpacity")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body.path = target
        body.shadowPath = target
        mask.path = target
        body.shadowOpacity = next.isExpanded ? 0.5 : 0
        CATransaction.commit()
    }

    /// Opens a throwaway island once on every tab, off screen and unseen (a few
    /// seconds after launch, once starting up has settled), so
    /// SwiftUI's one-time setup of those views (a few dozen milliseconds, enough
    /// to drop frames) is done before anyone opens the real one.
    static func warmUp(geometry: NotchGeometry, services: AppServices) async {
        let model = NotchViewModel(geometry: geometry)
        model.isExpanded = true
        let size = NotchViewModel.windowSize
        let window = NSWindow(contentRect: NSRect(x: -30_000, y: -30_000, width: size.width, height: size.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.transient, .ignoresCycle, .canJoinAllSpaces]
        let view = IslandView(model: model, root: NotchRootView(model: model, services: services, expand: {}, openSettings: {}))
        window.contentView = view
        window.orderFrontRegardless()
        for tab in NotchViewModel.Tab.allCases {
            model.tab = tab
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            CATransaction.flush()
            try? await Task.sleep(for: .milliseconds(80))
        }
        model.isExpanded = false
        window.orderOut(nil)
        window.contentView = nil
    }

    /// The same springs as `NotchAnimation`, chosen by what changed; with
    /// Reduce Motion on, a short ease instead.
    private static func motion(from previous: State, to next: State) -> (String, CGPath?, CGPath) -> CAAnimation {
        let (duration, bounce): (Double, Double) =
            if previous.isExpanded != next.isExpanded {
                next.isExpanded ? (0.5, 0.18) : (0.4, 0.12)
            } else if next.isExpanded {
                (0.45, 0.08)
            } else if previous.isHovering != next.isHovering, previous.size.height == next.size.height {
                (0.3, 0.25)
            } else {
                (0.45, 0.22)
            }
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        return { keyPath, from, to in
            if reduced {
                let ease = CABasicAnimation(keyPath: keyPath)
                ease.fromValue = from
                ease.toValue = to
                ease.duration = 0.2
                ease.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                return ease
            }
            let spring = CASpringAnimation(perceptualDuration: duration, bounce: bounce)
            spring.keyPath = keyPath
            spring.fromValue = from
            spring.toValue = to
            spring.duration = spring.settlingDuration
            return spring
        }
    }
}

/// A plain view with its origin at the top left, like SwiftUI's.
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// The island for SwiftUI screens (the preview on the Dynamic Island page).
struct IslandRepresentable: NSViewRepresentable {
    let model: NotchViewModel
    let services: AppServices

    func makeNSView(context: Context) -> IslandView {
        IslandView(model: model, root: NotchRootView(model: model, services: services, expand: {}, openSettings: {}))
    }

    func updateNSView(_ view: IslandView, context: Context) {}
}
