import CoreGraphics

/// How much of a screen other windows hide, for pausing things nobody can see.
public enum ScreenCoverage {
    /// The share of `frame` (0...1) that none of `rects` cover, sampled on a
    /// coarse grid: plenty to tell "a strip by the Dock" from "half the desktop".
    public static func uncoveredFraction(of frame: CGRect, by rects: [CGRect], columns: Int = 32, rows: Int = 20) -> Double {
        let relevant = rects.filter { $0.intersects(frame) }
        guard !relevant.isEmpty, frame.width > 0, frame.height > 0 else { return 1 }
        var uncovered = 0
        for row in 0..<rows {
            let y = frame.minY + (Double(row) + 0.5) * frame.height / Double(rows)
            for column in 0..<columns {
                let point = CGPoint(x: frame.minX + (Double(column) + 0.5) * frame.width / Double(columns), y: y)
                if !relevant.contains(where: { $0.contains(point) }) { uncovered += 1 }
            }
        }
        return Double(uncovered) / Double(columns * rows)
    }
}
