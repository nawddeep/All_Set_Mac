import CoreGraphics

/// The desktop's widget slots: squares a quarter the area of a small widget, `spacing`
/// apart, centered in the screen's visible area. Every widget size spans whole
/// cells (small 2×2, medium 4×2, large 4×4, extra large 8×4), so widgets placed here line
/// up with each other and never overlap. Works in the coordinates
/// `WidgetInstance.offset` uses (layout points, origin top-left, y down).
public struct WidgetGrid: Equatable, Sendable {
    public struct Cell: Hashable, Sendable {
        public var column: Int
        public var row: Int
        public init(column: Int, row: Int) {
            self.column = column
            self.row = row
        }
    }

    /// From one cell's top-left to the next: half a small widget plus its gap, so
    /// a small widget covers 2×2 cells and an extra small one a single cell.
    public static let pitch = (WidgetSize.small.dimensions.width + WidgetLayout.spacing) / 2

    public let columns: Int
    public let rows: Int
    /// Top-left of the first cell.
    public let origin: CGPoint

    /// `margin` is the least room left at each edge, in layout points: pass
    /// the screen margin divided by the widget size, so a grid at any size
    /// keeps the same margin on screen as `WidgetLayout.fitted` does.
    public init(bounds: CGSize, margin: CGFloat = WidgetLayout.margin) {
        let spacing = WidgetLayout.spacing
        let usable = CGSize(width: bounds.width - 2 * margin + spacing,
                            height: bounds.height - 2 * margin + spacing)
        // A hair of tolerance: a theme fitted edge to edge fills it exactly.
        columns = max(Int((usable.width / Self.pitch + 0.001).rounded(.down)), 1)
        rows = max(Int((usable.height / Self.pitch + 0.001).rounded(.down)), 1)
        let width = CGFloat(columns) * Self.pitch - spacing
        let height = CGFloat(rows) * Self.pitch - spacing
        origin = CGPoint(x: max(((bounds.width - width) / 2).rounded(), 0),
                         y: max(((bounds.height - height) / 2).rounded(), 0))
    }

    /// How many cells a size covers across and down.
    public static func span(of size: WidgetSize) -> (columns: Int, rows: Int) {
        span(of: size.dimensions)
    }

    /// How many cells a footprint reaches into across and down: whole cells,
    /// so a resized widget keeps a full gap to its neighbours.
    public static func span(of footprint: CGSize) -> (columns: Int, rows: Int) {
        func cells(_ length: CGFloat) -> Int {
            // A hair of tolerance: the four sizes span exactly 1, 2 or 4.
            max(Int(((length + WidgetLayout.spacing) / pitch - 0.01).rounded(.up)), 1)
        }
        return (cells(footprint.width), cells(footprint.height))
    }

    public func fits(_ size: WidgetSize) -> Bool {
        fits(size.dimensions)
    }

    public func fits(_ footprint: CGSize) -> Bool {
        let span = Self.span(of: footprint)
        return span.columns <= columns && span.rows <= rows
    }

    /// The largest footprint the grid holds.
    public var capacity: CGSize {
        CGSize(width: CGFloat(columns) * Self.pitch - WidgetLayout.spacing,
               height: CGFloat(rows) * Self.pitch - WidgetLayout.spacing)
    }

    public func offset(of cell: Cell) -> CGPoint {
        CGPoint(x: origin.x + CGFloat(cell.column) * Self.pitch, y: origin.y + CGFloat(cell.row) * Self.pitch)
    }

    /// The cell whose top-left is closest to `offset`, kept so a widget of
    /// `size` starting there stays on the grid. Nil when the size is larger
    /// than the whole grid.
    public func nearestCell(to offset: CGPoint, size: WidgetSize) -> Cell? {
        nearestCell(to: offset, footprint: size.dimensions)
    }

    public func nearestCell(to offset: CGPoint, footprint size: CGSize) -> Cell? {
        guard fits(size) else { return nil }
        let span = Self.span(of: size)
        let column = Int(((offset.x - origin.x) / Self.pitch).rounded())
        let row = Int(((offset.y - origin.y) / Self.pitch).rounded())
        return Cell(column: min(max(column, 0), columns - span.columns), row: min(max(row, 0), rows - span.rows))
    }

    /// The free spot nearest to `offset` for a widget of `size`, clear of
    /// every rect in `occupied`. Nil when nothing is free.
    public func place(_ size: WidgetSize, near offset: CGPoint, avoiding occupied: [CGRect]) -> CGPoint? {
        place(size.dimensions, near: offset, avoiding: occupied)
    }

    public func place(_ size: CGSize, near offset: CGPoint, avoiding occupied: [CGRect]) -> CGPoint? {
        var taken = Occupancy(self)
        occupied.forEach { taken.mark($0) }
        return taken.nearestFree(size, to: offset).map(offset(of:))
    }

    /// The first free spot, filling columns from the left as macOS does
    /// (desktop icons live top right). Nil when nothing is free.
    public func firstFree(_ size: WidgetSize, avoiding occupied: [CGRect]) -> CGPoint? {
        firstFree(size.dimensions, avoiding: occupied)
    }

    public func firstFree(_ size: CGSize, avoiding occupied: [CGRect]) -> CGPoint? {
        guard fits(size) else { return nil }
        var taken = Occupancy(self)
        occupied.forEach { taken.mark($0) }
        let span = Self.span(of: size)
        for column in 0...(columns - span.columns) {
            for row in 0...(rows - span.rows) {
                let cell = Cell(column: column, row: row)
                if taken.isFree(cell, span: span) { return offset(of: cell) }
            }
        }
        return nil
    }

    /// The widgets tidied onto the grid: each moves to the free cell nearest
    /// where it is, the whole group first shifted onto the grid so an
    /// arrangement already built from cells (a theme's) keeps its shape.
    /// Larger widgets choose first, except `kept`, which chooses before all
    /// of them: one just resized holds its spot and the rest make room. A
    /// widget with no free cell left stays where it is, inside the screen.
    /// Running it again changes nothing.
    public func arranged(_ widgets: [WidgetInstance], keeping kept: WidgetInstance.ID? = nil) -> [WidgetInstance] {
        guard let first = widgets.first else { return widgets }
        let box = widgets.dropFirst().reduce(CGRect(origin: first.offset, size: first.footprint)) {
            $0.union(CGRect(origin: $1.offset, size: $1.footprint))
        }
        let shift = CGPoint(x: ((box.minX - origin.x) / Self.pitch).rounded() * Self.pitch + origin.x - box.minX,
                            y: ((box.minY - origin.y) / Self.pitch).rounded() * Self.pitch + origin.y - box.minY)
        let order = widgets.indices.sorted { a, b in
            if let kept, (widgets[a].id == kept) != (widgets[b].id == kept) { return widgets[a].id == kept }
            let areaA = widgets[a].footprint.width * widgets[a].footprint.height
            let areaB = widgets[b].footprint.width * widgets[b].footprint.height
            if areaA != areaB { return areaA > areaB }
            if widgets[a].offset.y != widgets[b].offset.y { return widgets[a].offset.y < widgets[b].offset.y }
            return widgets[a].offset.x < widgets[b].offset.x
        }
        var taken = Occupancy(self)
        var result = widgets
        let bounds = CGSize(width: CGFloat(columns) * Self.pitch - WidgetLayout.spacing + 2 * origin.x,
                            height: CGFloat(rows) * Self.pitch - WidgetLayout.spacing + 2 * origin.y)
        for index in order {
            let widget = widgets[index]
            let wanted = CGPoint(x: widget.offset.x + shift.x, y: widget.offset.y + shift.y)
            if let cell = taken.nearestFree(widget.footprint, to: wanted) {
                taken.claim(cell, span: Self.span(of: widget.footprint))
                result[index].offset = offset(of: cell)
            } else {
                result[index].offset = WidgetLayout.clamp(widget.offset, size: widget.footprint, within: bounds)
            }
        }
        return result
    }

    /// Widgets already on the grid, opened up to fill it: whole empty cells
    /// are slipped in between them, across and down, wherever no widget
    /// reaches over, and what can't be spread evenly is split between the two
    /// edges. A wide screen then doesn't leave a theme with bare sides.
    public func spread(_ widgets: [WidgetInstance]) -> [WidgetInstance] {
        stretched(stretched(widgets, vertical: false), vertical: true)
    }

    private func stretched(_ widgets: [WidgetInstance], vertical: Bool) -> [WidgetInstance] {
        guard widgets.count > 1 else { return widgets }
        let start = vertical ? origin.y : origin.x
        let total = vertical ? rows : columns
        let ranges: [Range<Int>] = widgets.map { widget in
            let first = Int((((vertical ? widget.offset.y : widget.offset.x) - start) / Self.pitch).rounded())
            let span = Self.span(of: widget.footprint)
            return first..<(first + (vertical ? span.rows : span.columns))
        }
        guard let low = ranges.map(\.lowerBound).min(), let high = ranges.map(\.upperBound).max() else { return widgets }
        let extra = total - (high - low)
        guard extra > 0, low >= 0, high <= total else { return widgets }
        // Seams: lines between two cells that no widget crosses.
        let seams = ((low + 1)..<max(high, low + 1)).filter { seam in !ranges.contains { $0.lowerBound < seam && seam < $0.upperBound } }
        var inserted: [Int: Int] = [:]
        var placed = 0
        if !seams.isEmpty {
            for step in 1...extra {
                let target = Double(low) + Double(high - low) * Double(step) / Double(extra + 1)
                let seam = seams.min { abs(Double($0) - target) < abs(Double($1) - target) }!
                // At most two cells at one seam: a wider hole reads as a gap, not spacing.
                if inserted[seam, default: 0] < 2 { inserted[seam, default: 0] += 1; placed += 1 }
            }
        }
        let leading = (extra - placed) / 2
        return widgets.enumerated().map { index, widget in
            let first = ranges[index].lowerBound
            let shifted = first - low + leading + inserted.filter { $0.key <= first }.values.reduce(0, +)
            var widget = widget
            let moved = start + CGFloat(shifted) * Self.pitch
            if vertical { widget.offset.y = moved } else { widget.offset.x = moved }
            return widget
        }
    }

    /// Which cells are taken.
    private struct Occupancy {
        let grid: WidgetGrid
        var taken: Set<Cell> = []

        init(_ grid: WidgetGrid) {
            self.grid = grid
        }

        /// Marks every cell a rect reaches into, gaps included, so a widget
        /// off the grid still keeps others clear of it.
        mutating func mark(_ rect: CGRect) {
            let inner = rect.insetBy(dx: 1, dy: 1)
            guard !inner.isNull, !inner.isEmpty else { return }
            let half = WidgetLayout.spacing / 2
            for column in 0..<grid.columns {
                for row in 0..<grid.rows {
                    let cell = Cell(column: column, row: row)
                    let corner = grid.offset(of: cell)
                    let square = CGRect(x: corner.x - half, y: corner.y - half, width: WidgetGrid.pitch, height: WidgetGrid.pitch)
                    if square.intersects(inner) { taken.insert(cell) }
                }
            }
        }

        mutating func claim(_ cell: Cell, span: (columns: Int, rows: Int)) {
            for column in cell.column..<(cell.column + span.columns) {
                for row in cell.row..<(cell.row + span.rows) {
                    taken.insert(Cell(column: column, row: row))
                }
            }
        }

        func isFree(_ cell: Cell, span: (columns: Int, rows: Int)) -> Bool {
            for column in cell.column..<(cell.column + span.columns) {
                for row in cell.row..<(cell.row + span.rows) where taken.contains(Cell(column: column, row: row)) {
                    return false
                }
            }
            return true
        }

        func nearestFree(_ size: CGSize, to offset: CGPoint) -> Cell? {
            guard grid.fits(size) else { return nil }
            let span = WidgetGrid.span(of: size)
            var best: (cell: Cell, distance: CGFloat)?
            for row in 0...(grid.rows - span.rows) {
                for column in 0...(grid.columns - span.columns) {
                    let cell = Cell(column: column, row: row)
                    guard isFree(cell, span: span) else { continue }
                    let corner = grid.offset(of: cell)
                    let distance = (corner.x - offset.x) * (corner.x - offset.x) + (corner.y - offset.y) * (corner.y - offset.y)
                    if let current = best, distance >= current.distance - 0.5 { continue }
                    best = (cell, distance)
                }
            }
            return best?.cell
        }
    }
}

extension WidgetLayout {
    /// Widgets laid out for one screen size, carried to another: the same
    /// picture, scaled with the screen, centered the same relative way, and
    /// never bigger than the new screen holds. `fillsScreen` says the picture
    /// took most of the screen, so it should keep doing so.
    public static func refit(_ widgets: [WidgetInstance], from fit: ScreenFit, toScreen size: CGSize, visible: CGSize,
                             range: ClosedRange<Double>) -> (widgets: [WidgetInstance], scale: Double, fillsScreen: Bool) {
        guard let first = widgets.first, fit.width > 0, fit.height > 0 else { return (widgets, fit.scale, false) }
        let box = widgets.dropFirst().reduce(CGRect(origin: first.offset, size: first.footprint)) {
            $0.union(CGRect(origin: $1.offset, size: $1.footprint))
        }
        guard box.width > 0, box.height > 0 else { return (widgets, fit.scale, false) }
        let ratio = min(size.width / CGFloat(fit.width), size.height / CGFloat(fit.height))
        var scale = min(max(fit.scale * Double(ratio), range.lowerBound), range.upperBound)
        scale = min(scale, Double((visible.width - 2 * margin) / box.width), Double((visible.height - 2 * margin) / box.height))
        scale = max(scale, range.lowerBound)
        let factor = CGFloat(scale)
        // Where the picture's middle was on the old screen, as a share of it.
        let middle = CGPoint(x: box.midX * CGFloat(fit.scale) / CGFloat(fit.width) * size.width,
                             y: box.midY * CGFloat(fit.scale) / CGFloat(fit.height) * size.height)
        let half = CGSize(width: box.width * factor / 2, height: box.height * factor / 2)
        let center = CGPoint(x: min(max(middle.x, margin + half.width), max(visible.width - margin - half.width, margin + half.width)),
                             y: min(max(middle.y, margin + half.height), max(visible.height - margin - half.height, margin + half.height)))
        let shift = CGPoint(x: center.x / factor - box.width / 2 - box.minX, y: center.y / factor - box.height / 2 - box.minY)
        let moved = widgets.map { widget -> WidgetInstance in
            var widget = widget
            widget.offset = CGPoint(x: widget.offset.x + shift.x, y: widget.offset.y + shift.y)
            return widget
        }
        let fills = max(box.width * factor / visible.width, box.height * factor / visible.height) >= 0.8
        return (moved, scale, fills)
    }
}
