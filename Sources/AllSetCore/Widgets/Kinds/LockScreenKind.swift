import Foundation

// `WidgetKind.lockScreen`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let lockScreen = WidgetKindDefinition(
        kind: .lockScreen, category: .aesthetic, title: "Lock Screen", symbol: "lock.fill",
        summary: "A big clock over a photo, like your iPhone",
        keywords: "iphone depth clock photo",
        sizes: [.small, .medium, .large], defaultSize: .medium,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .photo
            instance.options.clockFace = .stacked
            instance.options.background = CuratedBackgrounds.photo(id: "65").map(ImageSource.web)
        })
}
