import AllSetCore
import AppKit
import Observation

/// A borderless panel that sits on the desktop: above the desktop icons, below
/// every app window, on every Space, and left alone by Mission Control.
final class WidgetWindow: NSPanel {
    /// Room around the widget for its shadow and the arrange-mode buttons.
    static let margin: CGFloat = 16
    static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    /// While arranging, widgets float above windows so they can all be reached.
    static let arrangingLevel = NSWindow.Level.floating

    /// Only notes take keyboard focus; other widgets shouldn't pull it away
    /// from the app being used.
    var allowsKey = false

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = Self.desktopLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
    }

    let state = WidgetWindowState()

    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }

    /// How far into the widget, in its own points, the corner reaches.
    static let cornerReach: CGFloat = 40

    /// Shows the resize handle while the pointer (screen coordinates) is over
    /// the widget's bottom-right corner and nothing is on top of it.
    func pointerMoved(to point: CGPoint) {
        var inCorner = false
        if frame.contains(point) {
            let scale = state.contentScale
            let margin = Self.margin * scale, reach = Self.cornerReach * scale
            // The corner runs out into the margin, where the handle sits.
            inCorner = point.x >= frame.maxX - margin - reach && point.y <= frame.minY + margin + reach
        }
        if state.cornerHovered != inCorner { state.cornerHovered = inCorner }
    }
}

/// One widget window's live state. Each window has its own, so a widget being
/// covered or resized redraws that widget alone, not every one on the desktop.
@Observable @MainActor
final class WidgetWindowState {
    var isOccluded = false
    /// The pointer is over the widget's bottom-right corner.
    var cornerHovered = false
    /// The corner handle is being dragged.
    var isResizing = false
    /// The size and scale shown while the corner is dragged; saved on release.
    var liveSize: WidgetSize?
    var liveScale: Double?
    var liveStretch: Double?
    /// Window points per layout point, for finding the corner.
    @ObservationIgnored var contentScale: CGFloat = 1
}
