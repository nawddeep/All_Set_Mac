import AllSetCore
import AppKit
import SwiftUI

#if DEBUG
extension WidgetRenderHarness {
    /// Native-size screenshots using the same fitting rule as installation.
    static func renderSuppliedDesktops(_ set: ThemeSet, to folder: URL, services: AppServices) async {
        let layout = ThemeComposition.widgets(for: set, dark: set.isDark, services: services)
        for bounds in [CGSize(width: 1440, height: 900), CGSize(width: 1920, height: 1080)] {
            let fitted = FunkyThemes.fitted(layout, in: bounds)
            let view = ZStack(alignment: .topLeading) {
                ThemeWallpaper(set: set, services: services, dark: set.isDark)
                    .frame(width: bounds.width, height: bounds.height)
                ForEach(fitted.widgets) { widget in
                    WidgetBody(instance: widget, services: services)
                        .shadow(color: .black.opacity(widget.hasCard ? 0.2 : 0), radius: 7, y: 3)
                        .scaleEffect(fitted.scale, anchor: .topLeading)
                        .offset(x: widget.offset.x * fitted.scale, y: widget.offset.y * fitted.scale)
                }
            }
            .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
            .environment(\.widgetIsVisible, false)
            .environment(\.widgetIsPreview, true)
            .environment(\.colorScheme, set.isDark ? .dark : .light)
            if let image = await capture(view, size: bounds),
               let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try? png.write(to: folder.appendingPathComponent("desktop-\(set.id)-\(Int(bounds.width))x\(Int(bounds.height)).png"))
            }
        }
    }
}
#endif
