import Foundation

// `WidgetKind.magazine`: what the gallery, the inspector and the grid know about it.
// Its view lives in Sources/AllSet/Widgets/Kinds; register a new kind in WidgetKindDefinition.all.
extension WidgetKindDefinition {
    static let magazine = WidgetKindDefinition(
        kind: .magazine, category: .aesthetic, title: "Magazine Cover", symbol: "newspaper.fill",
        summary: "Today as the cover of a magazine",
        keywords: "magazine cover editorial vogue date headline",
        sizes: [.small, .large], defaultSize: .large,
        isFreeform: false, paintsOwnBackground: false,
        defaults: { instance in
            instance.material = .glass
            instance.options.designTheme = DesignTheme.editorial.id
        })
}
