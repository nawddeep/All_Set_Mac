import Foundation

// `WidgetKind.vinyl`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let vinyl = WidgetKindDefinition(
        kind: .vinyl, category: .aesthetic, title: "Vinyl", symbol: "opticaldisc.fill",
        summary: "A record that spins while music plays",
        keywords: "record music spin",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            // They paint their own backgrounds.
            instance.material = .dark
        })
}
