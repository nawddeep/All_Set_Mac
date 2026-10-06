// Pictures stacked into one, each under a label and scaled to the same width:
// for putting a design reference above a screenshot of the build.
//
//     xcrun swift scripts/stack-images.swift out.png [--width 1400] "Label" picture.png x,y,w,h …
//
// Each picture takes three arguments: its label, its path, and the part of
// it to show, in its own pixels from the top left ("-" for all of it).
// `scripts/review-hero.sh` runs this for the Themes hero.

import AppKit

var arguments = Array(CommandLine.arguments.dropFirst())
guard !arguments.isEmpty else {
    print("usage: stack-images out.png [--width 1400] \"Label\" picture.png x,y,w,h …")
    exit(2)
}
let output = arguments.removeFirst()
var width: CGFloat = 1400
if let flag = arguments.firstIndex(of: "--width"), flag + 1 < arguments.count {
    width = CGFloat(Double(arguments[flag + 1]) ?? 1400)
    arguments.removeSubrange(flag...(flag + 1))
}

var rows: [(label: String, image: CGImage)] = []
while arguments.count >= 3 {
    let label = arguments.removeFirst(), path = arguments.removeFirst(), part = arguments.removeFirst()
    guard let picture = NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("stack-images: can't read \(path)")
        exit(1)
    }
    let numbers = part.split(separator: ",").compactMap { Double($0) }
    let whole = CGRect(x: 0, y: 0, width: picture.width, height: picture.height)
    let crop = numbers.count == 4 ? CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3]).intersection(whole) : whole
    rows.append((label, picture.cropping(to: crop) ?? picture))
}

let labelHeight: CGFloat = 44
let heights = rows.map { width * CGFloat($0.image.height) / CGFloat($0.image.width) }
let total = heights.reduce(0, +) + labelHeight * CGFloat(rows.count)
guard let canvas = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(total), bitsPerSample: 8,
                                    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                    bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: canvas) else { exit(1) }
NSGraphicsContext.current = context
// The app's canvas color, so the pictures sit on what they'd sit on in the window.
NSColor(red: 0.027, green: 0.035, blue: 0.059, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: total).fill()
context.cgContext.interpolationQuality = .high
var y = total
for (row, height) in zip(rows, heights) {
    y -= labelHeight
    NSAttributedString(string: row.label, attributes: [.font: NSFont.systemFont(ofSize: 20, weight: .semibold),
                                                       .foregroundColor: NSColor.white])
        .draw(at: NSPoint(x: 16, y: y + 10))
    y -= height
    context.cgContext.draw(row.image, in: CGRect(x: 0, y: y, width: width, height: height))
}
context.flushGraphics()
guard let png = canvas.representation(using: .png, properties: [:]) else { exit(1) }
do {
    try png.write(to: URL(fileURLWithPath: output))
} catch {
    print("stack-images: \(error.localizedDescription)")
    exit(1)
}
