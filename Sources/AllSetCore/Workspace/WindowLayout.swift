import CoreGraphics

/// Something the window manager can do to the frontmost window.
public enum WindowAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case firstThird, centerThird, lastThird
    case firstTwoThirds, lastTwoThirds
    case maximize, almostMaximize, center
    case restore, nextDisplay, previousDisplay

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .firstThird: "First Third"
        case .centerThird: "Center Third"
        case .lastThird: "Last Third"
        case .firstTwoThirds: "First Two Thirds"
        case .lastTwoThirds: "Last Two Thirds"
        case .maximize: "Maximize"
        case .almostMaximize: "Almost Maximize"
        case .center: "Center"
        case .restore: "Restore"
        case .nextDisplay: "Next Display"
        case .previousDisplay: "Previous Display"
        }
    }

    /// Grouped for the settings list.
    public enum Group: String, CaseIterable, Identifiable, Sendable {
        case halves, quarters, thirds, whole, displays

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .halves: "Halves"
            case .quarters: "Quarters"
            case .thirds: "Thirds"
            case .whole: "Size"
            case .displays: "Displays"
            }
        }
    }

    public var group: Group {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf: .halves
        case .topLeft, .topRight, .bottomLeft, .bottomRight: .quarters
        case .firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds: .thirds
        case .maximize, .almostMaximize, .center, .restore: .whole
        case .nextDisplay, .previousDisplay: .displays
        }
    }
}

/// Window geometry, in AppKit screen coordinates (origin bottom-left, y up).
public enum WindowLayout {
    /// Whether macOS is tiling windows dragged to screen edges itself, which
    /// All Set's snapping then stays out of the way of. That arrived in macOS
    /// 15; before it there's nothing to defer to. On 15 and later an absent
    /// preference means its default, on.
    public static func nativeTilingIsOn(preference: Bool?, osMajor: Int) -> Bool {
        guard osMajor >= 15 else { return false }
        return preference ?? true
    }

    /// Where `action` puts a window on a screen whose usable area is `visible`.
    /// With `cycle`, repeating Left or Right Half steps through ½, ⅔ and ⅓.
    /// Returns nil for actions that need more than one screen or history.
    public static func frame(for action: WindowAction, window: CGRect, visible: CGRect,
                             gap: CGFloat = 0, cycle: Bool = true) -> CGRect? {
        // Half a gap off the screen's edges here and half around each window
        // gives a full gap everywhere: at the edges and between windows.
        let area = visible.insetBy(dx: gap / 2, dy: gap / 2)
        func place(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: area.minX + area.width * x, y: area.minY + area.height * y,
                   width: area.width * w, height: area.height * h)
                .insetBy(dx: gap / 2, dy: gap / 2)
                .integral
        }

        switch action {
        case .leftHalf, .rightHalf:
            let left = action == .leftHalf
            let widths: [CGFloat] = [1 / 2, 2 / 3, 1 / 3]
            var width = widths[0]
            if cycle, let index = widths.firstIndex(where: { w in
                approximatelyEqual(window, place(left ? 0 : 1 - w, 0, w, 1))
            }) {
                width = widths[(index + 1) % widths.count]
            }
            return place(left ? 0 : 1 - width, 0, width, 1)
        case .topHalf: return place(0, 0.5, 1, 0.5)
        case .bottomHalf: return place(0, 0, 1, 0.5)
        case .topLeft: return place(0, 0.5, 0.5, 0.5)
        case .topRight: return place(0.5, 0.5, 0.5, 0.5)
        case .bottomLeft: return place(0, 0, 0.5, 0.5)
        case .bottomRight: return place(0.5, 0, 0.5, 0.5)
        case .firstThird: return place(0, 0, 1 / 3, 1)
        case .centerThird: return place(1 / 3, 0, 1 / 3, 1)
        case .lastThird: return place(2 / 3, 0, 1 / 3, 1)
        case .firstTwoThirds: return place(0, 0, 2 / 3, 1)
        case .lastTwoThirds: return place(1 / 3, 0, 2 / 3, 1)
        case .maximize: return place(0, 0, 1, 1)
        case .almostMaximize: return place(0.05, 0.05, 0.9, 0.9)
        case .center:
            let width = min(window.width, area.width)
            let height = min(window.height, area.height)
            return CGRect(x: area.midX - width / 2, y: area.midY - height / 2, width: width, height: height).integral
        case .restore, .nextDisplay, .previousDisplay:
            return nil
        }
    }

    /// The same relative spot and size on another screen, for moving a window
    /// between displays.
    public static func move(_ window: CGRect, from source: CGRect, to destination: CGRect) -> CGRect {
        guard source.width > 0, source.height > 0 else { return window }
        let x = (window.minX - source.minX) / source.width
        let y = (window.minY - source.minY) / source.height
        let width = min(window.width / source.width, 1)
        let height = min(window.height / source.height, 1)
        return CGRect(x: destination.minX + x * destination.width, y: destination.minY + y * destination.height,
                      width: width * destination.width, height: height * destination.height).integral
    }

    /// The snap for a window dropped with the pointer at `point`: screen edges
    /// give halves (the top edge maximizes), corners give quarters, and the
    /// bottom edge gives thirds. `screen` is the whole screen, menu bar included.
    public static func snapZone(at point: CGPoint, screen: CGRect, edge: CGFloat = 6, corner: CGFloat = 60) -> WindowAction? {
        let nearLeft = point.x <= screen.minX + edge
        let nearRight = point.x >= screen.maxX - edge
        let nearTop = point.y >= screen.maxY - edge
        let nearBottom = point.y <= screen.minY + edge
        let inTopCorner = point.y >= screen.maxY - corner
        let inBottomCorner = point.y <= screen.minY + corner
        let inLeftCorner = point.x <= screen.minX + corner
        let inRightCorner = point.x >= screen.maxX - corner

        if nearLeft {
            return inTopCorner ? .topLeft : inBottomCorner ? .bottomLeft : .leftHalf
        }
        if nearRight {
            return inTopCorner ? .topRight : inBottomCorner ? .bottomRight : .rightHalf
        }
        if nearTop {
            return inLeftCorner ? .topLeft : inRightCorner ? .topRight : .maximize
        }
        if nearBottom {
            let third = (point.x - screen.minX) / screen.width
            return third < 1 / 3 ? .firstThird : third < 2 / 3 ? .centerThird : .lastThird
        }
        return nil
    }

    /// Converts between AppKit's bottom-left-origin coordinates and the
    /// top-left-origin ones the Accessibility API uses; the conversion is its
    /// own inverse. `primaryHeight` is the height of the menu bar screen.
    public static func flipped(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func approximatelyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 4) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }
}
