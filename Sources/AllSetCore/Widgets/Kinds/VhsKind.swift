import Foundation

// `WidgetKind.vhs`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let vhs = WidgetKindDefinition(
        kind: .vhs, category: .music, title: "VHS", symbol: "video.fill",
        summary: "A photo on an old tape, tracking lines and all",
        keywords: "vhs video tape camcorder retro 90s vintage film americana",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: true,
        defaults: { instance in
            instance.material = .dark
            instance.options.images = CuratedBackgrounds.collection("Palm Sunsets").prefix(1).map(ImageSource.web)
            instance.options.caption = "SUMMER 1996"
        })
}
