import Foundation

// `WidgetKind.photo`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let photo = WidgetKindDefinition(
        kind: .photo, category: .lifestyle, title: "Photo", symbol: "photo.fill",
        summary: "Your photos, art or a slideshow",
        keywords: "picture image slideshow collage gallery",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .glass
            instance.options.images = [.art(ArtPiece(style: .dunes, palette: .desert))]
        })
}
