import CoreGraphics
import Foundation
import ImageIO

/// A quiet accent taken from a picture, for themes that follow the wallpaper.
/// Only a 64-pixel thumbnail is decoded, so a 6K desktop picture costs about
/// as much as an icon.
public enum WallpaperColor {
    /// The most characterful color of the picture at `url`: vivid pixels weigh
    /// more than dull ones, so a colorful subject beats a gray sky. Nil when
    /// the file can't be read or the picture has no color to speak of.
    public static func accent(of url: URL) -> WidgetColor? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 64,
            kCGImageSourceShouldCacheImmediately: false,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return accent(of: thumbnail)
    }

    public static func accent(of image: CGImage) -> WidgetColor? {
        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        var red = 0.0, green = 0.0, blue = 0.0, weight = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let color = WidgetColor(red: Double(pixels[index]) / 255, green: Double(pixels[index + 1]) / 255,
                                    blue: Double(pixels[index + 2]) / 255)
            let (_, saturation, value) = color.hsv
            // Vivid, mid-bright pixels define the picture's color.
            let w = 0.02 + pow(saturation, 2) * value * (1 - abs(value - 0.6))
            red += color.red * w
            green += color.green * w
            blue += color.blue * w
            weight += w
        }
        guard weight > 0 else { return nil }
        let average = WidgetColor(red: red / weight, green: green / weight, blue: blue / weight)
        return average.hsv.1 < 0.12 ? nil : average
    }
}
