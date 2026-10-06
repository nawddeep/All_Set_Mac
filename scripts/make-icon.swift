// Draws the All Set app icon and writes Resources/AppIcon.icns.
// Run with: swift scripts/make-icon.swift
import AppKit

let side: CGFloat = 1024
// macOS icon grid: the shape is 824 pt with room for its shadow.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let corner: CGFloat = 185

func color(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func glow(_ context: CGContext, center: CGPoint, radius: CGFloat, hex: Int, alpha: CGFloat) {
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [color(hex, alpha), color(hex, 0)] as CFArray, locations: [0, 1])!
    context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
    let context = NSGraphicsContext.current!.cgContext
    let shape = CGPath(roundedRect: body, cornerWidth: corner, cornerHeight: corner, transform: nil)

    // Drop shadow under the shape.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: color(0x000000, 0.35))
    context.addPath(shape)
    context.setFillColor(color(0x1B1464))
    context.fillPath()
    context.restoreGState()

    // Background: deep indigo with glowing color, like the app's Glow art.
    context.saveGState()
    context.addPath(shape)
    context.clip()
    let base = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                          colors: [color(0x0B0A2E), color(0x2A1470)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(base, start: CGPoint(x: body.minX, y: body.maxY), end: CGPoint(x: body.maxX, y: body.minY), options: [])
    glow(context, center: CGPoint(x: 300, y: 330), radius: 520, hex: 0xFF3E8A, alpha: 0.85)
    glow(context, center: CGPoint(x: 780, y: 260), radius: 460, hex: 0xFF9F43, alpha: 0.7)
    glow(context, center: CGPoint(x: 760, y: 720), radius: 480, hex: 0x4CC9F0, alpha: 0.65)
    glow(context, center: CGPoint(x: 260, y: 760), radius: 400, hex: 0x8E2DE2, alpha: 0.8)

    // The Dynamic Island.
    let island = CGRect(x: side / 2 - 190, y: body.maxY - 150, width: 380, height: 100)
    context.setShadow(offset: CGSize(width: 0, height: -6), blur: 24, color: color(0x000000, 0.5))
    context.addPath(CGPath(roundedRect: island, cornerWidth: 50, cornerHeight: 50, transform: nil))
    context.setFillColor(color(0x000000))
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0, color: nil)
    // A camera dot and a little now-playing waveform inside it.
    context.setFillColor(color(0x1E2240))
    context.fillEllipse(in: CGRect(x: island.minX + 38, y: island.midY - 17, width: 34, height: 34))
    let bars: [CGFloat] = [28, 52, 38, 60]
    for (index, height) in bars.enumerated() {
        let x = island.maxX - 118 + CGFloat(index) * 22
        let rect = CGRect(x: x, y: island.midY - height / 2, width: 12, height: height)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil))
        context.setFillColor(color(0x5BF0B0))
        context.fillPath()
    }

    // "All set": a bold checkmark with a soft glow.
    let check = CGMutablePath()
    check.move(to: CGPoint(x: 330, y: 470))
    check.addLine(to: CGPoint(x: 460, y: 345))
    check.addLine(to: CGPoint(x: 705, y: 610))
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setShadow(offset: .zero, blur: 40, color: color(0xFFFFFF, 0.6))
    context.addPath(check)
    context.setStrokeColor(color(0xFFFFFF))
    context.setLineWidth(92)
    context.strokePath()
    context.restoreGState()

    // A faint rim of light along the edge.
    context.addPath(shape)
    context.setStrokeColor(color(0xFFFFFF, 0.18))
    context.setLineWidth(3)
    context.strokePath()
    return true
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func png(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    try! png(points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try! png(points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try! png(1024).write(to: root.appendingPathComponent("Resources/AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
