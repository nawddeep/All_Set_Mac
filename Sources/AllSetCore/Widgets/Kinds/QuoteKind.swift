import Foundation

// `WidgetKind.quote`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let quote = WidgetKindDefinition(
        kind: .quote, category: .lifestyle, title: "Quote", symbol: "quote.opening",
        summary: "Words to live by, beautifully set",
        keywords: "affirmation words motivation reminder poster text",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .art
            instance.options.art = ArtPiece(style: .blobs, palette: .lavender)
            instance.options.animateArt = false
        })
}
