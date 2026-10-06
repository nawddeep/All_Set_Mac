import SwiftUI

/// The notch silhouette: flush with the top edge, flaring outward into the menu
/// bar at the top corners, rounded at the bottom.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = min(topCornerRadius, rect.width / 4, rect.height / 2)
        let bottom = max(min(bottomCornerRadius, (rect.width - 2 * top) / 2, rect.height - top), 0)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY + top),
                          control: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.minX + top, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.maxX - top, y: rect.maxY),
                    radius: bottom)
        path.addArc(tangent1End: CGPoint(x: rect.maxX - top, y: rect.maxY),
                    tangent2End: CGPoint(x: rect.maxX - top, y: rect.minY + top),
                    radius: bottom)
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
