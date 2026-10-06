import AppKit

enum ArtworkPalette {
    /// A color from the artwork that reads well on black. Vivid pixels count
    /// more than dull ones, so a small colorful subject beats a gray backdrop.
    static func accentColor(for image: NSImage) -> NSColor? {
        let side = 12
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()

        var red = 0.0, green = 0.0, blue = 0.0, weight = 0.0
        for x in 0..<side {
            for y in 0..<side {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let w = 0.05 + color.saturationComponent * color.brightnessComponent
                red += color.redComponent * w
                green += color.greenComponent * w
                blue += color.blueComponent * w
                weight += w
            }
        }
        guard weight > 0 else { return nil }

        let average = NSColor(deviceRed: red / weight, green: green / weight, blue: blue / weight, alpha: 1)
        guard average.saturationComponent >= 0.15 else { return NSColor(white: 0.92, alpha: 1) }
        return NSColor(hue: average.hueComponent,
                       saturation: min(average.saturationComponent * 1.2, 0.85),
                       brightness: max(average.brightnessComponent, 0.8),
                       alpha: 1)
    }
}
