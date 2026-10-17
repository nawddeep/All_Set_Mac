import Foundation

// `WidgetKind.note`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let note = WidgetKindDefinition(
        kind: .note, category: .productivity, title: "Note", symbol: "note.text",
        summary: "A sticky note for the desktop",
        keywords: "sticky memo text",
        sizes: [.small, .medium, .large], defaultSize: .small,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            instance.material = .glass
        })
}
