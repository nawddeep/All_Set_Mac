import Foundation

// `WidgetKind.ambient`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let ambient = WidgetKindDefinition(
        kind: .ambient, category: .aesthetic, title: "Live Scene", symbol: "sparkles",
        summary: "Animated art with the time on top",
        keywords: "animated art scene live",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            instance.material = .art
            instance.options.art = ArtPiece(style: .aurora, palette: .aurora)
        })
}
