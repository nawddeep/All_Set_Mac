import Foundation

// `WidgetKind.polaroids`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let polaroids = WidgetKindDefinition(
        kind: .polaroids, category: .aesthetic, title: "Polaroids", symbol: "photo.stack.fill",
        summary: "A little pile of prints. Click to shuffle",
        keywords: "photos prints instant film",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: true, paintsOwnBackground: true,
        defaults: { instance in
            // Prints lying on the desktop, with no card behind them.
            instance.material = .dark
            instance.options.images = CuratedBackgrounds.polaroidStarters.map(ImageSource.web)
            instance.options.slideshowInterval = 0
        })
}
