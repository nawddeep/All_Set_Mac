import Foundation

// `WidgetKind.date`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let date = WidgetKindDefinition(
        kind: .date, category: .time, title: "Date", symbol: "calendar.day.timeline.left",
        summary: "Today's date, big and clear",
        keywords: "day today calendar",
        sizes: [.small, .medium], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            // The everyday widgets start in the native look.
            instance.material = .glass
            instance.options.designTheme = DesignTheme.native.id
        })
}
