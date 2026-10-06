import AppKit
import SwiftUI

/// A soft-edged rounded rectangle as a stretchable picture, drawn once.
/// Cards take their shadow and their glow from it, tinted with
/// `foregroundStyle` and faded with `opacity`, so nothing has a blur or a
/// shadow to redo while it moves: only a picture to composite.
struct CardHalo: View {
    /// How far the soft edge spreads, in points.
    enum Spread: CGFloat, CaseIterable {
        case shadow = 18
        case glow = 36
    }

    let spread: Spread

    var body: some View {
        if let image = Self.images[spread] {
            let cap = Self.reach(spread) + Self.corner
            Image(decorative: image, scale: 1)
                .renderingMode(.template)
                .resizable(capInsets: EdgeInsets(top: cap, leading: cap, bottom: cap, trailing: cap))
                // The picture's solid middle sits exactly under the card.
                .padding(-Self.reach(spread))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// The cards' corner radius (`DS.Radius.panel`).
    private static let corner: CGFloat = 20

    /// Room around the middle for the edge to fade out completely.
    private static func reach(_ spread: Spread) -> CGFloat { (spread.rawValue * 1.5).rounded() }

    private static let images: [Spread: CGImage] = Dictionary(uniqueKeysWithValues: Spread.allCases.compactMap { spread in
        draw(spread).map { (spread, $0) }
    })

    private static func draw(_ spread: Spread) -> CGImage? {
        let reach = reach(spread)
        // One point between the corners is all the stretching needs.
        let side = Int((reach + corner) * 2) + 1
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let white = CGColor(gray: 1, alpha: 1)
        context.setShadow(offset: .zero, blur: spread.rawValue, color: white)
        context.setFillColor(white)
        let middle = CGRect(x: reach, y: reach, width: CGFloat(side) - reach * 2, height: CGFloat(side) - reach * 2)
        context.addPath(CGPath(roundedRect: middle, cornerWidth: corner, cornerHeight: corner, transform: nil))
        context.fillPath()
        return context.makeImage()
    }
}
