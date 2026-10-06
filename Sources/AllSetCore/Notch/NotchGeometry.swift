import CoreGraphics

/// Where the notch sits on a screen. Screens without one get a virtual notch
/// of typical size, centered in the menu bar.
public struct NotchGeometry: Equatable, Sendable {
    public var screenFrame: CGRect
    /// In global screen coordinates (AppKit, bottom-left origin).
    public var notchRect: CGRect
    public var hasPhysicalNotch: Bool

    public static let virtualNotchWidth: CGFloat = 185

    /// - Parameters:
    ///   - safeAreaTop: `NSScreen.safeAreaInsets.top`; non-zero only with a notch.
    ///   - topLeftArea: `NSScreen.auxiliaryTopLeftArea`, the menu bar left of the notch.
    ///   - topRightArea: `NSScreen.auxiliaryTopRightArea`.
    ///   - menuBarHeight: Height for the virtual notch when there's no real one.
    public init(screenFrame: CGRect, safeAreaTop: CGFloat, topLeftArea: CGRect?, topRightArea: CGRect?,
                menuBarHeight: CGFloat) {
        self.screenFrame = screenFrame
        // Only the widths of the side areas are used, which sidesteps whether
        // they're in screen-local or global coordinates.
        if safeAreaTop > 0, let left = topLeftArea, let right = topRightArea {
            let width = screenFrame.width - left.width - right.width
            if width > 0 {
                notchRect = CGRect(x: screenFrame.minX + left.width, y: screenFrame.maxY - safeAreaTop,
                                   width: width, height: safeAreaTop)
                hasPhysicalNotch = true
                return
            }
        }
        let width = Self.virtualNotchWidth
        let height = menuBarHeight > 0 ? menuBarHeight : 24
        notchRect = CGRect(x: screenFrame.midX - width / 2, y: screenFrame.maxY - height, width: width, height: height)
        hasPhysicalNotch = false
    }

    /// A rect of `size` hanging from the top of the screen, centered on the notch.
    public func hangingRect(size: CGSize) -> CGRect {
        CGRect(x: notchRect.midX - size.width / 2, y: screenFrame.maxY - size.height,
               width: size.width, height: size.height)
    }
}
