import CoreGraphics
import Foundation

/// A landscape desktop in the spotlight, framed by portrait neighbours.
/// Geometry follows distance continuously, so swipes also morph each card.
public struct ThemeCarouselLayout: Equatable, Sendable {
    public static let cardAspect: CGFloat = 1136.0 / 768
    public static let sideAspect: CGFloat = 0.75
    public static let gap: CGFloat = 12
    public static let reach = 2
    public let panelSize: CGSize
    public let cardSize: CGSize

    public init(viewport: CGSize, margin: CGFloat, chrome: CGFloat, footer: CGFloat) {
        let width = max(viewport.width - margin * 2, 0)
        let target = min(max(viewport.height * 0.66, 290), 540)
        let height = max(min(target - chrome, width * 0.34 / Self.cardAspect), 0)
        cardSize = CGSize(width: height * Self.cardAspect, height: height)
        panelSize = CGSize(width: width, height: height + chrome)
    }

    public func size(at distance: CGFloat) -> CGSize {
        let prominence = max(1 - abs(distance), 0)
        let aspect = Self.sideAspect + (Self.cardAspect - Self.sideAspect) * prominence
        return CGSize(width: cardSize.height * aspect, height: cardSize.height)
    }

    public func offset(at distance: CGFloat, flat: Bool = false) -> CGFloat {
        let away = abs(distance)
        let first = cardSize.width / 2 + halfWidth(1, flat: flat) + Self.gap
        let next = halfWidth(1, flat: flat) + halfWidth(2, flat: flat) + Self.gap
        let along = away <= 1 ? first * away : first + next * (away - 1)
        return distance < 0 ? -along : along
    }

    public func step(flat: Bool = false) -> CGFloat { offset(at: 1, flat: flat) }

    private func halfWidth(_ distance: CGFloat, flat: Bool) -> CGFloat {
        let depth = ThemeCarouselDepth(distance: distance, flat: flat)
        return size(at: distance).width * depth.scale / 2 * cos(depth.tilt * .pi / 180)
    }
}

public struct ThemeCarouselDepth: Equatable, Sendable {
    public let scale: CGFloat
    public let dim: CGFloat
    public let opacity: CGFloat
    public let tilt: CGFloat
    public let dip: CGFloat
    public let glow: CGFloat

    public init(distance: CGFloat, flat: Bool = false, reach: Int = ThemeCarouselLayout.reach) {
        let away = abs(distance)
        scale = max(1 - 0.09 * min(away, 3), 0.73)
        dim = min(0.1 * away, 0.35)
        opacity = min(max(1 - 2 * (away - CGFloat(reach)), 0), 1)
        let turn = min(12 * away, 20)
        tilt = flat ? 0 : (distance < 0 ? turn : -turn)
        dip = min(away, 3) * 8
        glow = max(0, 1 - away)
    }
}
