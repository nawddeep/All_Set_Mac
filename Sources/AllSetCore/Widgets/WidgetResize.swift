import CoreGraphics
import Foundation

/// Turns a widget's corner being dragged into a size and a scale.
///
/// Width and height follow the pointer independently, so any size is possible.
/// The layout it was designed with (small, medium, large, extra large) that is
/// closest in shape and size is the one stretched, so the distortion stays small:
/// dragging a small much wider turns it medium, and so on.
public enum WidgetResize {
    /// How much a size's shape counts against its scale when choosing.
    static let scaleWeight = 0.35
    /// The size being dragged keeps a head start, so the layout doesn't flick
    /// back and forth when the pointer sits near the point between two.
    static let stickiness = 0.12
    /// Within this of its own size, a widget settles back to exactly it.
    public static let snapToNatural = 0.03

    public struct Result: Equatable, Sendable {
        public var size: WidgetSize
        public var scale: Double
        public var stretch: Double

        public init(size: WidgetSize, scale: Double, stretch: Double = 1) {
            self.size = size
            self.scale = scale
            self.stretch = stretch
        }

        public var footprint: CGSize {
            CGSize(width: size.dimensions.width * scale, height: size.dimensions.height * scale * stretch)
        }
    }

    /// - Parameters:
    ///   - dragged: the size the pointer asks for, in layout points.
    ///   - current: the size shown right now (it gets the head start).
    ///   - sizes: the sizes this kind can take; empty means `current` only.
    ///   - room: the most space there is (the grid's capacity), if limited.
    public static func resolve(_ dragged: CGSize, current: WidgetSize, sizes: [WidgetSize],
                               room: CGSize? = nil) -> Result {
        let width = max(Double(dragged.width), 1), height = max(Double(dragged.height), 1)
        // A size too big for the room even at its smallest is no choice.
        let minimum = WidgetInstance.scaleRange.lowerBound
        let roomy = (sizes.isEmpty ? [current] : sizes).filter { size in
            guard let room else { return true }
            return Double(size.dimensions.width) * minimum <= Double(room.width)
                && Double(size.dimensions.height) * minimum <= Double(room.height)
        }
        let candidates = roomy.isEmpty ? [current] : roomy
        var best: (size: WidgetSize, cost: Double)?
        for size in candidates {
            let natural = size.dimensions
            let aspect = abs(log((width / height) / Double(natural.width / natural.height)))
            let scale = ((width / Double(natural.width)) * (height / Double(natural.height))).squareRoot()
            var cost = aspect + scaleWeight * abs(log(scale))
            if size == current { cost -= stickiness }
            if best == nil || cost < best!.cost { best = (size, cost) }
        }
        let size = best?.size ?? current
        let natural = size.dimensions
        let lower = WidgetInstance.scaleRange.lowerBound, upper = WidgetInstance.scaleRange.upperBound
        // Width and height are each followed freely; the layout only sets the starting shape.
        var horizontal = width / Double(natural.width), vertical = height / Double(natural.height)
        if abs(horizontal - 1) < snapToNatural, abs(vertical - 1) < snapToNatural { horizontal = 1; vertical = 1 }
        let roomX = room.map { Double($0.width / natural.width) } ?? upper
        let roomY = room.map { Double($0.height / natural.height) } ?? upper
        horizontal = min(max(horizontal, lower), max(min(upper, roomX), lower))
        vertical = min(max(vertical, 0.2), max(min(upper * 2, roomY), 0.2))
        let stretch = min(max(vertical / horizontal, WidgetInstance.stretchRange.lowerBound), WidgetInstance.stretchRange.upperBound)
        return Result(size: size, scale: horizontal, stretch: stretch)
    }
}

extension WidgetResize {
    /// Extra small: the small layout at about half size,     /// control and still fits a quarter of a cell's space.
    public static let extraSmallScale = 0.45
}

extension WidgetInstance {
    public var isExtraSmall: Bool {
        size == .small && abs(scale - WidgetResize.extraSmallScale) < 0.005 && stretch == 1
    }
}
