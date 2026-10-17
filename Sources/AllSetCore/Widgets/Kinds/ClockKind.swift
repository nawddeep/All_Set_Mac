import Foundation

// `WidgetKind.clock`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    // Designed for the extra-large size too.
    static let clock = WidgetKindDefinition(
        kind: .clock, category: .time, title: "Clock", symbol: "clock.fill",
        summary: "Digital or analog, any time zone",
        keywords: "time watch flip digital analog world",
        sizes: [.small, .medium, .large, .extraLarge], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .photo
            instance.options.background = CuratedBackgrounds.photo(id: "830").map(ImageSource.web)
        })
}
