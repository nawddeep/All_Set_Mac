import CoreGraphics
import Foundation
import Testing
@testable import AllSetCore

@Suite struct WidgetResizeTests {
    private let all: [WidgetSize] = [.small, .medium, .large, .extraLarge]

    private func drag(_ width: CGFloat, _ height: CGFloat, from current: WidgetSize = .small,
                      sizes: [WidgetSize]? = nil, room: CGSize? = nil) -> WidgetResize.Result {
        WidgetResize.resolve(CGSize(width: width, height: height), current: current, sizes: sizes ?? all, room: room)
    }

    @Test func lettingGoNearItsOwnSizeSettlesExactlyOnIt() {
        #expect(drag(168, 168) == .init(size: .small, scale: 1))
        #expect(drag(171, 166) == .init(size: .small, scale: 1))
        #expect(drag(352, 168, from: .medium) == .init(size: .medium, scale: 1))
    }

    @Test func anythingInBetweenIsTheSameLayoutScaled() {
        let result = drag(220, 220)
        #expect(result.size == .small)
        #expect(abs(result.scale - 220.0 / 168) < 0.001)
        #expect(abs(result.footprint.width - 220) < 0.01)
    }

    @Test func draggingWiderTurnsSquareIntoWide() {
        #expect(drag(352, 170).size == .medium)
        #expect(drag(740, 350, from: .large).size == .extraLarge)
        // Back again.
        #expect(drag(180, 170, from: .medium).size == .small)
    }

    @Test func draggingMuchBiggerTakesTheRoomierLayout() {
        #expect(drag(340, 340).size == .large)
        #expect(drag(180, 180, from: .large).size == .small)
    }

    @Test func theLayoutDoesNotFlickerNearTheChangeover() {
        // Between the two, each keeps the layout it already has.
        for side in stride(from: 215.0, through: 280.0, by: 5) {
            #expect(drag(side, side, from: .small).size == .small)
            #expect(drag(side, side, from: .large).size == .large)
        }
    }

    @Test func onlyTheKindsOwnSizesAreOffered() {
        // A kind without a wide layout scales its square one instead.
        let result = drag(352, 168, sizes: [.small, .large])
        #expect(result.size == .small)
        #expect(drag(500, 260, from: .medium, sizes: [.medium, .large, .extraLarge]).size != .small)
    }

    @Test func staysWithinTheScaleRangeAndTheRoom() {
        #expect(drag(20, 20).scale == WidgetInstance.scaleRange.lowerBound)
        #expect(drag(5000, 5000, sizes: [.small]).scale == WidgetInstance.scaleRange.upperBound)
        let room = CGSize(width: 500, height: 300)
        let result = drag(900, 900, from: .large, room: room)
        #expect(result.footprint.width <= room.width + 0.01 && result.footprint.height <= room.height + 0.01)
        // Extra large doesn't fit at all, even at its smallest: never chosen.
        #expect(drag(900, 430, from: .large, room: CGSize(width: 250, height: 250)).size != .extraLarge)
    }

    @Test func widthAndHeightFollowThePointerIndependently() {
        let result = drag(300, 180)
        #expect(abs(result.footprint.width - 300) < 0.01 && abs(result.footprint.height - 180) < 0.01)
        let tall = drag(168, 400)
        #expect(abs(tall.footprint.width - 168) < 0.01 && abs(tall.footprint.height - 400) < 0.01)
    }

    @Test func nonsenseInputStillGivesAUsableSize() {
        let result = drag(0, -50)
        #expect(result.scale >= WidgetInstance.scaleRange.lowerBound && result.scale.isFinite)
    }
}

@Suite struct WidgetFootprintTests {
    private let bounds = CGSize(width: 1470, height: 923)

    @Test func footprintIsTheSizeScaled() {
        var widget = WidgetInstance(kind: .clock, size: .medium)
        #expect(widget.footprint == WidgetSize.medium.dimensions)
        widget.scale = 1.5
        #expect(widget.footprint == CGSize(width: 528, height: 252))
    }

    @Test func aScaledWidgetTakesEveryCellItReaches() {
        #expect(WidgetGrid.span(of: WidgetSize.small) == (2, 2))
        #expect(WidgetGrid.span(of: WidgetSize.extraLarge) == (8, 4))
        // 1.3 × small is 218 points: into a third cell each way.
        #expect(WidgetGrid.span(of: CGSize(width: 218.4, height: 218.4)) == (3, 3))
        // 0.7 × medium is 246 × 118: three cells across, two down.
        #expect(WidgetGrid.span(of: CGSize(width: 246.4, height: 117.6)) == (3, 2))
    }

    @Test func aResizedWidgetKeepsItsSpotAndTheOthersMakeRoom() {
        let grid = WidgetGrid(bounds: bounds)
        var grown = WidgetInstance(kind: .clock, size: .small, offset: grid.offset(of: .init(column: 0, row: 0)))
        let neighbour = WidgetInstance(kind: .calendar, size: .small, offset: grid.offset(of: .init(column: 1, row: 0)))
        let below = WidgetInstance(kind: .system, size: .small, offset: grid.offset(of: .init(column: 0, row: 1)))
        grown.scale = 1.6
        let arranged = grid.arranged([neighbour, below, grown], keeping: grown.id)
        let byID = Dictionary(uniqueKeysWithValues: arranged.map { ($0.id, $0) })
        #expect(byID[grown.id]?.offset == grown.offset)
        let rects = arranged.map { CGRect(origin: $0.offset, size: $0.footprint) }
        for (index, rect) in rects.enumerated() {
            for other in rects[(index + 1)...] {
                #expect(!rect.intersects(other.insetBy(dx: 1, dy: 1)))
            }
        }
        // Tidying again changes nothing.
        #expect(grid.arranged(arranged) == arranged)
    }

    @Test func layoutsSavedBeforeResizingLoadAtTheirOwnSize() throws {
        let old = WidgetInstance(kind: .clock, size: .medium)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
        json.removeValue(forKey: "scale")
        let loaded = try JSONDecoder().decode(WidgetInstance.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(loaded.scale == 1)
        json["scale"] = 40
        let clamped = try JSONDecoder().decode(WidgetInstance.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(clamped.scale == WidgetInstance.scaleRange.upperBound)
    }

    @Test func aResizedWidgetSurvivesSavingAndLoading() throws {
        var widget = WidgetInstance(kind: .weather, size: .large)
        widget.scale = 1.27
        let loaded = try JSONDecoder().decode(WidgetInstance.self, from: JSONEncoder().encode(widget))
        #expect(loaded == widget)
    }
}
