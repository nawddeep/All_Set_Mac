import Foundation

// `WidgetKind.nextEvent`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let nextEvent = WidgetKindDefinition(
        kind: .nextEvent, category: .productivity, title: "Next Event", symbol: "calendar.badge.clock",
        summary: "What's next on your calendar, and when",
        keywords: "meeting event calendar upcoming schedule",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            // The everyday widgets start in the native look.
            instance.material = .glass
            instance.options.designTheme = DesignTheme.native.id
        })
}
