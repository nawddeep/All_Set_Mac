import AppKit
import CoreImage
import Foundation

/// One change to a picture, in its pixels, origin top-left.
public struct ScreenshotEdit: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        /// Keep only this rectangle.
        case crop
        /// Blur this rectangle.
        case blur
        /// Cover this rectangle with a solid block.
        case redact
        /// A translucent marker over this rectangle.
        case highlight
        /// An outline around this rectangle.
        case box
        /// An arrow from (x, y) to (toX, toY).
        case arrow
        /// `text` with its top-left at (x, y).
        case text
    }

    public enum Color: String, Codable, CaseIterable, Sendable {
        case red, orange, yellow, green, blue, purple, white, black

        var nsColor: NSColor {
            switch self {
            case .red: .systemRed
            case .orange: .systemOrange
            case .yellow: .systemYellow
            case .green: .systemGreen
            case .blue: .systemBlue
            case .purple: .systemPurple
            case .white: .white
            case .black: .black
            }
        }
    }

    public var kind: Kind
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var toX: Double
    public var toY: Double
    public var text: String
    public var color: Color

    public init(kind: Kind, x: Double, y: Double, width: Double = 0, height: Double = 0,
                toX: Double = 0, toY: Double = 0, text: String = "", color: Color = .red) {
        self.kind = kind
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.toX = toX
        self.toY = toY
        self.text = text
        self.color = color
    }

    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height).standardized }

    /// The same edit in a picture `factor` times larger.
    public func scaled(by factor: Double) -> ScreenshotEdit {
        var edit = self
        edit.x *= factor
        edit.y *= factor
        edit.width *= factor
        edit.height *= factor
        edit.toX *= factor
        edit.toY *= factor
        return edit
    }
}

/// What the AI answered: a reply to show, and the edits to make.
public struct EditPlan: Codable, Equatable, Sendable {
    public var reply: String
    public var edits: [ScreenshotEdit]

    public init(reply: String, edits: [ScreenshotEdit]) {
        self.reply = reply
        self.edits = edits
    }
}

/// Draws edits onto a picture.
public enum ScreenshotRenderer {
    public static func apply(_ edits: [ScreenshotEdit], to image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: bounds)
        // Edits arrive top-left based; Core Graphics draws bottom-left based.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        let graphics = NSGraphicsContext(cgContext: context, flipped: true)
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = graphics
        defer { NSGraphicsContext.current = previous }

        let line = max(3, CGFloat(min(width, height)) / 220)
        var crop: CGRect?
        /// Every redaction, filled again after everything else: nothing drawn later
        /// (a blur, a highlight, a label) can show what it hides.
        var redactions: [CGRect] = []
        for edit in edits {
            let rect = edit.rect.intersection(bounds)
            switch edit.kind {
            case .crop:
                // Crops from several requests narrow down together; drawn last.
                if rect.width >= 4, rect.height >= 4 {
                    let narrowed = crop.map { $0.intersection(rect) } ?? rect
                    if narrowed.width >= 4, narrowed.height >= 4 { crop = narrowed }
                }
            case .blur:
                // Made from the picture as edited so far, never the original: a blur
                // over an earlier redaction must blur black, not what was under it.
                guard !rect.isEmpty, let current = context.makeImage(), let blurred = blur(current, rect: rect) else { continue }
                context.saveGState()
                context.translateBy(x: rect.minX, y: rect.maxY)
                context.scaleBy(x: 1, y: -1)
                context.draw(blurred, in: CGRect(origin: .zero, size: rect.size))
                context.restoreGState()
            case .redact:
                context.setFillColor(NSColor.black.cgColor)
                context.fill(rect)
                redactions.append(rect)
            case .highlight:
                context.saveGState()
                context.setBlendMode(.multiply)
                context.setFillColor(edit.color.nsColor.withAlphaComponent(0.45).cgColor)
                context.fill(rect)
                context.restoreGState()
            case .box:
                context.setStrokeColor(edit.color.nsColor.cgColor)
                context.setLineWidth(line)
                context.addPath(CGPath(roundedRect: rect, cornerWidth: line * 2, cornerHeight: line * 2, transform: nil))
                context.strokePath()
            case .arrow:
                drawArrow(from: CGPoint(x: edit.x, y: edit.y), to: CGPoint(x: edit.toX, y: edit.toY),
                          color: edit.color.nsColor.cgColor, width: line * 1.4, in: context)
            case .text:
                drawLabel(edit.text, at: CGPoint(x: edit.x, y: edit.y), color: edit.color.nsColor,
                          size: max(16, CGFloat(height) / 32))
            }
        }
        // Redactions are authoritative: filled last, over anything drawn after them.
        if !redactions.isEmpty {
            context.saveGState()
            context.setBlendMode(.copy)
            context.setFillColor(NSColor.black.cgColor)
            context.fill(redactions)
            context.restoreGState()
        }
        guard let result = context.makeImage() else { return nil }
        if let crop {
            return result.cropping(to: crop.integral) ?? result
        }
        return result
    }

    private static func blur(_ image: CGImage, rect: CGRect) -> CGImage? {
        let source = CIImage(cgImage: image)
        // Core Image counts from the bottom.
        let region = CGRect(x: rect.minX, y: CGFloat(image.height) - rect.maxY, width: rect.width, height: rect.height)
        let radius = max(6, min(rect.width, rect.height) / 5)
        let blurred = source.cropped(to: region).clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: region)
        return CIContext().createCGImage(blurred, from: region)
    }

    private static func drawArrow(from start: CGPoint, to end: CGPoint, color: CGColor, width: CGFloat, in context: CGContext) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let head = width * 4.5
        let base = CGPoint(x: end.x - cos(angle) * head * 0.8, y: end.y - sin(angle) * head * 0.8)
        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.move(to: start)
        context.addLine(to: base)
        context.strokePath()
        context.move(to: end)
        context.addLine(to: CGPoint(x: end.x - cos(angle - .pi / 7) * head, y: end.y - sin(angle - .pi / 7) * head))
        context.addLine(to: CGPoint(x: end.x - cos(angle + .pi / 7) * head, y: end.y - sin(angle + .pi / 7) * head))
        context.closePath()
        context.fillPath()
    }

    /// Text on a rounded pill so it reads on any background.
    private static func drawLabel(_ text: String, at point: CGPoint, color: NSColor, size: CGFloat) {
        guard !text.isEmpty else { return }
        let dark = color == .white || color == .systemYellow
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .bold),
            .foregroundColor: dark ? NSColor.black : NSColor.white,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let textSize = string.size()
        let padding = size * 0.35
        let pill = CGRect(x: point.x, y: point.y, width: textSize.width + padding * 2, height: textSize.height + padding)
        color.setFill()
        NSBezierPath(roundedRect: pill, xRadius: pill.height / 2.6, yRadius: pill.height / 2.6).fill()
        string.draw(at: CGPoint(x: pill.minX + padding, y: pill.minY + padding / 2))
    }
}
