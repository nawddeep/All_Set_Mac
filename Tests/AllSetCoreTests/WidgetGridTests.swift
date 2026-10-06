import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite struct WidgetGridTests {
    /// This Mac's visible desktop at widget size 1: 1470 × 923 points.
    private let airBounds = CGSize(width: 1470, height: 923)

    private func frames(_ widgets: [WidgetInstance]) -> [CGRect] {
        widgets.map { CGRect(origin: $0.offset, size: $0.size.dimensions) }
    }

    private func expectNoOverlaps(_ widgets: [WidgetInstance], sourceLocation: SourceLocation = #_sourceLocation) {
        let rects = frames(widgets)
        for (index, rect) in rects.enumerated() {
            for other in rects[(index + 1)...] {
                #expect(!rect.intersects(other.insetBy(dx: 1, dy: 1)), sourceLocation: sourceLocation)
            }
        }
    }

    private func expectOnGrid(_ widgets: [WidgetInstance], _ grid: WidgetGrid, sourceLocation: SourceLocation = #_sourceLocation) {
        for widget in widgets {
            let column = (widget.offset.x - grid.origin.x) / WidgetGrid.pitch
            let row = (widget.offset.y - grid.origin.y) / WidgetGrid.pitch
            #expect(column == column.rounded() && row == row.rounded(), sourceLocation: sourceLocation)
            let span = WidgetGrid.span(of: widget.size)
            #expect(Int(column) >= 0 && Int(column) + span.columns <= grid.columns, sourceLocation: sourceLocation)
            #expect(Int(row) >= 0 && Int(row) + span.rows <= grid.rows, sourceLocation: sourceLocation)
        }
    }

    @Test func gridFitsTheScreenAndIsCentered() {
        let grid = WidgetGrid(bounds: airBounds)
        #expect(grid.columns == 15 && grid.rows >= 8)
        let width = CGFloat(grid.columns) * WidgetGrid.pitch - WidgetLayout.spacing
        #expect(abs(grid.origin.x - (airBounds.width - width) / 2) <= 0.5)
        #expect(grid.origin.x >= WidgetLayout.margin && grid.origin.y >= WidgetLayout.margin)
        // Bigger widgets mean fewer, larger slots.
        let larger = WidgetGrid(bounds: CGSize(width: airBounds.width / 1.4, height: airBounds.height / 1.4))
        #expect(larger.columns == 11 && larger.rows == 7)
    }

    @Test func everySizeSpansWholeCells() {
        #expect(WidgetGrid.span(of: .small) == (2, 2))
        #expect(WidgetGrid.span(of: .medium) == (4, 2))
        #expect(WidgetGrid.span(of: .large) == (4, 4))
        #expect(WidgetGrid.span(of: .extraLarge) == (8, 4))
    }

    @Test func aDropLandsInTheNearestFreeSlot() {
        let grid = WidgetGrid(bounds: airBounds)
        let first = grid.offset(of: .init(column: 0, row: 0))
        // Dropped right on top of a widget already there: the next slot over.
        let taken = CGRect(origin: first, size: WidgetSize.small.dimensions)
        let spot = grid.place(.small, near: CGPoint(x: first.x + 10, y: first.y + 5), avoiding: [taken])
        #expect(spot == grid.offset(of: .init(column: 0, row: 2)) || spot == grid.offset(of: .init(column: 2, row: 0)))
        // Dropped past the edge: kept on the screen.
        let edge = grid.place(.medium, near: CGPoint(x: 5000, y: -300), avoiding: [])
        #expect(edge == grid.offset(of: .init(column: grid.columns - 4, row: 0)))
        // A full grid has no slot.
        let everything = CGRect(x: 0, y: 0, width: airBounds.width, height: airBounds.height)
        #expect(grid.place(.small, near: .zero, avoiding: [everything]) == nil)
    }

    @Test func newWidgetsFillColumnsFromTheLeft() {
        let grid = WidgetGrid(bounds: airBounds)
        let first = grid.firstFree(.small, avoiding: [])
        #expect(first == grid.offset(of: .init(column: 0, row: 0)))
        let taken = CGRect(origin: first!, size: WidgetSize.small.dimensions)
        #expect(grid.firstFree(.small, avoiding: [taken]) == grid.offset(of: .init(column: 0, row: 2)))
    }

    @Test func cleanUpRemovesOverlapsAndLinesEverythingUp() {
        let grid = WidgetGrid(bounds: airBounds)
        // Strewn about, several on top of one another, one half off screen.
        let strewn: [WidgetInstance] = [
            WidgetInstance(kind: .clock, size: .medium, offset: CGPoint(x: 40, y: 31)),
            WidgetInstance(kind: .calendar, size: .small, offset: CGPoint(x: 60, y: 50)),
            WidgetInstance(kind: .system, size: .small, offset: CGPoint(x: 75, y: 60)),
            WidgetInstance(kind: .weather, size: .large, offset: CGPoint(x: 600, y: 200)),
            WidgetInstance(kind: .photo, size: .large, offset: CGPoint(x: 650, y: 230)),
            WidgetInstance(kind: .quote, size: .medium, offset: CGPoint(x: 1400, y: 880)),
        ]
        let tidy = grid.arranged(strewn)
        #expect(tidy.map(\.id) == strewn.map(\.id))
        expectNoOverlaps(tidy)
        expectOnGrid(tidy, grid)
        // A tidy desktop stays exactly as it is.
        #expect(frames(grid.arranged(tidy)) == frames(tidy))
    }

    @Test func spreadOpensUpTheGridToItsEdges() {
        let grid = WidgetGrid(bounds: airBounds)
        // A row of seven small widgets, 14 of the 15 columns: one empty cell slips in between.
        let row = (0..<7).map { WidgetInstance(kind: .clock, size: .small, offset: grid.offset(of: .init(column: $0 * 2, row: 3))) }
        let spread = grid.spread(row)
        expectNoOverlaps(spread)
        expectOnGrid(spread, grid)
        let right = spread.map { $0.offset.x + $0.footprint.width }.max()!
        #expect(abs(right - (grid.origin.x + grid.capacity.width)) < 0.5)
        // A single row has no seam to open down the screen: it is centered instead.
        #expect(Set(spread.map(\.offset.y)).count == 1)
        let top = spread[0].offset.y
        #expect(top == grid.origin.y + CGFloat((grid.rows - 2) / 2) * WidgetGrid.pitch)
    }

    @Test func cleanUpKeepsAThemesShape() {
        for set in ThemeLibrary.all {
            let layout = set.widgets(screenName: nil, bounds: CGSize(width: 10_000, height: 10_000))
            let fitted = WidgetLayout.fitted(layout, in: airBounds, range: 0.7...1.6)
            let bounds = CGSize(width: airBounds.width / fitted.scale, height: airBounds.height / fitted.scale)
            let themeGrid = WidgetGrid(bounds: bounds, margin: WidgetLayout.margin / fitted.scale)
            let tidy = themeGrid.arranged(fitted.widgets)
            expectNoOverlaps(tidy)
            // Every widget moved by the same amount: the composition is intact.
            let shifts = Set(zip(fitted.widgets, tidy).map {
                "\((($1.offset.x - $0.offset.x) * 10).rounded()),\((($1.offset.y - $0.offset.y) * 10).rounded())"
            })
            #expect(shifts.count == 1, "\(set.id) lost its shape")
        }
    }

    @Test func aGrownWidgetPushesNeighboursAside() {
        let grid = WidgetGrid(bounds: airBounds)
        let a = grid.offset(of: .init(column: 0, row: 0))
        let b = grid.offset(of: .init(column: 1, row: 0))
        var widgets = [
            WidgetInstance(kind: .clock, size: .small, offset: a),
            WidgetInstance(kind: .calendar, size: .small, offset: b),
        ]
        widgets[0].size = .large
        let tidy = grid.arranged(widgets)
        #expect(tidy[0].offset == a)
        expectNoOverlaps(tidy)
        expectOnGrid(tidy, grid)
    }
}

@Suite struct WidgetRefitTests {
    private func layout() -> [WidgetInstance] {
        [WidgetInstance(kind: .clock, size: .medium, offset: CGPoint(x: 100, y: 80)),
         WidgetInstance(kind: .weather, size: .small, offset: CGPoint(x: 100, y: 264)),
         WidgetInstance(kind: .photo, size: .large, offset: CGPoint(x: 468, y: 80))]
    }

    private func box(_ widgets: [WidgetInstance]) -> CGRect {
        widgets.dropFirst().reduce(CGRect(origin: widgets[0].offset, size: widgets[0].footprint)) {
            $0.union(CGRect(origin: $1.offset, size: $1.footprint))
        }
    }

    @Test func aBiggerScreenScalesTheSamePictureUp() {
        let fit = ScreenFit(scale: 1, size: CGSize(width: 1440, height: 900))
        let out = WidgetLayout.refit(layout(), from: fit, toScreen: CGSize(width: 2560, height: 1440),
                                     visible: CGSize(width: 2560, height: 1400), range: 0.4...2)
        #expect(out.scale > 1.5 && out.scale <= 2)
        // Same shape: every widget moved by the same amount.
        let shifts = Set(zip(layout(), out.widgets).map { "\(($1.offset.x - $0.offset.x).rounded()),\(($1.offset.y - $0.offset.y).rounded())" })
        #expect(shifts.count == 1)
        // On the new screen it still sits inside the margins.
        let drawn = box(out.widgets)
        #expect(drawn.maxX * out.scale <= 2560 - WidgetLayout.margin + 0.5 && drawn.maxY * out.scale <= 1400 - WidgetLayout.margin + 0.5)
        #expect(drawn.minX >= 0 && drawn.minY >= 0)
    }

    @Test func aSmallerScreenShrinksItToFit() {
        let fit = ScreenFit(scale: 1.4, size: CGSize(width: 2560, height: 1440))
        let wide = box(layout())
        let out = WidgetLayout.refit(layout(), from: fit, toScreen: CGSize(width: 1280, height: 720),
                                     visible: CGSize(width: 1280, height: 690), range: 0.4...2)
        #expect(out.scale < 1.4)
        #expect(wide.width * out.scale <= 1280 - 2 * WidgetLayout.margin + 0.5)
        #expect(wide.height * out.scale <= 690 - 2 * WidgetLayout.margin + 0.5)
    }

    @Test func aSameSizedScreenChangesNothing() {
        let fit = ScreenFit(scale: 1.1, size: CGSize(width: 1440, height: 900))
        let out = WidgetLayout.refit(layout(), from: fit, toScreen: CGSize(width: 1440, height: 900),
                                     visible: CGSize(width: 1440, height: 870), range: 0.4...2)
        #expect(abs(out.scale - 1.1) < 0.001)
        #expect(zip(layout(), out.widgets).allSatisfy { abs($0.offset.x - $1.offset.x) < 0.5 && abs($0.offset.y - $1.offset.y) < 0.5 })
    }
}
