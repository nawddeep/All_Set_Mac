import Foundation

// `WidgetKind.nowPlaying`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let nowPlaying = WidgetKindDefinition(
        kind: .nowPlaying, category: .lifestyle, title: "Now Playing", symbol: "music.note",
        summary: "Artwork and playback controls",
        keywords: "music spotify song player audio",
        sizes: [.small, .medium], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .glass
        })
}
