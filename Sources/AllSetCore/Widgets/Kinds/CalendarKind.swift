import Foundation

// `WidgetKind.calendar`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let calendar = WidgetKindDefinition(
        kind: .calendar, category: .productivity, title: "Calendar", symbol: "calendar",
        summary: "The month and what's coming up",
        keywords: "date month events schedule",
        sizes: [.small, .medium, .large], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .mesh
            instance.options.art = ArtPiece(style: .aurora, palette: .midnight)
        })
}
