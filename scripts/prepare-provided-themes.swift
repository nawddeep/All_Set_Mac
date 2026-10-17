#!/usr/bin/env swift
// Deterministic resource preparation for the user's supplied desktop mockups.
// Only explicitly selected artwork/photo regions are read. No painted clock,
// media control, menu bar or Dock is used as installed wallpaper content.
import AppKit
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let config = root.appendingPathComponent("design/provided-funky-themes/assets.json")
let data = try JSONSerialization.jsonObject(with: Data(contentsOf: config)) as! [String: Any]
let themes = data["themes"] as! [[String: Any]]
let output = root.appendingPathComponent("Sources/AllSetCore/Resources/ThemeArt")
let colorSpace = CGColorSpaceCreateDeviceRGB()

func color(_ hex: String, alpha: CGFloat = 1) -> CGColor {
    let value = UInt32(hex, radix: 16)!
    return CGColor(red: CGFloat((value >> 16) & 255) / 255,
                   green: CGFloat((value >> 8) & 255) / 255,
                   blue: CGFloat(value & 255) / 255, alpha: alpha)
}

func canvas(_ width: Int, _ height: Int) -> CGContext {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
              bytesPerRow: width * 4, space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func crop(_ image: CGImage, _ bounds: [Double]) -> CGImage {
    let w = Double(image.width), h = Double(image.height)
    let rect = CGRect(x: bounds[0] * w / 100, y: bounds[1] * h / 100,
                      width: (bounds[2] - bounds[0]) * w / 100,
                      height: (bounds[3] - bounds[1]) * h / 100).integral
    return image.cropping(to: rect)!
}

func save(_ image: CGImage, _ name: String) throws {
    let url = output.appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.94] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

for (index, theme) in themes.enumerated() {
    let id = theme["id"] as! String
    let sourceURL = URL(fileURLWithPath: theme["source"] as! String)
    let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil)!
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    let photos = theme["photoCrops"] as! [[Double]]
    for (number, bounds) in photos.enumerated() {
        // Keep the source's real pixel dimensions; don't manufacture detail.
        try save(crop(image, bounds), "edit-supplied-\(id)-photo-\(number).jpg")
    }

    // Paper, a restrained ink wash and source artwork form a clean desktop.
    // This native composition contains decoration only, never widget data.
    let width = 2880, height = 1800
    let context = canvas(width, height)
    let full = CGRect(x: 0, y: 0, width: width, height: height)
    context.setFillColor(color(theme["card"] as! String)); context.fill(full)
    var seed = UInt64(index + 1) * 13579
    func next() -> CGFloat {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
    }
    for _ in 0..<32000 {
        context.setFillColor(CGColor(gray: next() > 0.5 ? 1 : 0, alpha: 0.025))
        context.fill(CGRect(x: next() * 2880, y: next() * 1800, width: 1 + next() * 2, height: 1))
    }
    let accent = theme["accent"] as! String
    context.setFillColor(color(accent, alpha: 0.055))
    context.fill(CGRect(x: 80, y: 90, width: 690, height: 240))
    context.fill(CGRect(x: 850, y: 1500, width: 400, height: 190))

    let artwork = crop(image, theme["artCrop"] as! [Double])
    let layer = canvas(artwork.width, artwork.height)
    let artBounds = CGRect(x: 0, y: 0, width: artwork.width, height: artwork.height)
    layer.draw(artwork, in: artBounds)
    layer.setBlendMode(.destinationIn)
    let mask = CGGradient(colorsSpace: colorSpace,
                          colors: [CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 1),
                                   CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)] as CFArray,
                          locations: [0, 0.09, 0.95, 1])!
    layer.drawLinearGradient(mask, start: .zero, end: CGPoint(x: artwork.width, y: 0), options: [])
    let maxArtWidth: CGFloat = 1320, maxArtHeight: CGFloat = 1540
    let scale = min(maxArtWidth / CGFloat(artwork.width), maxArtHeight / CGFloat(artwork.height), 2.2)
    let artWidth = CGFloat(artwork.width) * scale, artHeight = CGFloat(artwork.height) * scale
    let left = (theme["wallpaperSide"] as! String) == "left"
    let x: CGFloat = left ? 70 : 2880 - artWidth - 65
    context.interpolationQuality = .high
    context.draw(layer.makeImage()!, in: CGRect(x: x, y: (1800 - artHeight) / 2, width: artWidth, height: artHeight))
    try save(context.makeImage()!, "edit-supplied-\(id).jpg")
    print("Prepared \(id): 2880×1800 clean composition + \(photos.count) source photos")
}
