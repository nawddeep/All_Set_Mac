import AllSetCore
import AppKit

/// The app windows covering the desktop right now. Reading window bounds
/// needs no screen-recording permission (only titles do).
@MainActor
enum DesktopCoverage {
    /// Ordinary app windows on screen, in Cocoa coordinates.
    static func windowRects() -> [CGRect] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else { return [] }
        // Window-server coordinates run down from the top of the main screen.
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return info.compactMap { window in
            guard (window[kCGWindowLayer as String] as? Int) == 0,
                  (window[kCGWindowAlpha as String] as? Double ?? 1) > 0.5,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds) else { return nil }
            return CGRect(x: rect.minX, y: mainHeight - rect.maxY, width: rect.width, height: rect.height)
        }
    }

    static func uncoveredFraction(of frame: CGRect, by rects: [CGRect]) -> Double {
        ScreenCoverage.uncoveredFraction(of: frame, by: rects)
    }
}
